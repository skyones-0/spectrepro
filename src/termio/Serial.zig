//! Native POSIX serial backend. It owns the callout device directly rather
//! than launching an external terminal program, so the terminal renderer and
//! serial control signals always operate on the same file descriptor.
const Serial = @This();

const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const posix = std.posix;
const global = @import("../global.zig");
const xev = global.xev;
const renderer = @import("../renderer.zig");
const terminal = @import("../terminal/main.zig");
const termio = @import("../termio.zig");
const internal_os = @import("../os/main.zig");
const fastmem = @import("../fastmem.zig");
const ProcessInfo = @import("../pty.zig").ProcessInfo;

const c = @cImport({
    @cInclude("errno.h");
    @cInclude("fcntl.h");
    @cInclude("termios.h");
    @cInclude("unistd.h");
    @cInclude("sys/ioctl.h");
    @cInclude("sys/ttycom.h");
});

const log = std.log.scoped(.io_serial);

/// Configuration is intentionally value-based so the C/Swift boundary can
/// create it without leaking UI objects into the IO thread.
pub const Config = struct {
    path: []const u8,
    baud_rate: u32 = 115_200,
    data_bits: u8 = 8,
    /// 0 none, 1 odd, 2 even.
    parity: u8 = 0,
    /// 1 or 2.
    stop_bits: u8 = 1,
    /// 0 none, 1 RTS/CTS, 2 XON/XOFF.
    flow_control: u8 = 0,
};

path: [:0]u8,
config: Config,
alloc: Allocator,

pub fn init(alloc: Allocator, config: Config) !Serial {
    const path = try alloc.dupeZ(u8, config.path);
    return .{ .path = path, .config = config, .alloc = alloc };
}

pub fn deinit(self: *Serial) void {
    self.alloc.free(self.path);
}

pub fn initTerminal(_: *Serial, _: *terminal.Terminal) void {}

pub fn threadEnter(self: *Serial, alloc: Allocator, io: *termio.Termio, td: *termio.Termio.ThreadData) !void {
    _ = alloc;
    if (builtin.os.tag != .macos) return error.UnsupportedOperatingSystem;

    const fd = c.open(self.path.ptr, c.O_RDWR | c.O_NOCTTY | c.O_NONBLOCK);
    if (fd < 0) return error.SerialOpenFailed;
    errdefer _ = c.close(fd);
    try configure(fd, self.config);

    const pipe = try internal_os.pipe();
    errdefer _ = posix.system.close(pipe[0]);
    errdefer _ = posix.system.close(pipe[1]);

    var stream = xev.Stream.initFd(fd);
    errdefer stream.deinit();

    const read_thread = try std.Thread.spawn(
        .{},
        termio.Exec.ReadThread.threadMainPosix,
        .{ fd, io, pipe[0] },
    );
    read_thread.setName(global.io(), "serial-reader") catch {};

    td.backend = .{ .serial = .{
        .fd = fd,
        .write_stream = stream,
        .read_thread = read_thread,
        .read_thread_pipe = pipe[1],
    } };
}

pub fn threadExit(_: *Serial, td: *termio.Termio.ThreadData) void {
    const data = &td.backend.serial;
    switch (posix.errno(posix.system.write(data.read_thread_pipe, "x", 1))) {
        .SUCCESS, .PIPE => {},
        else => |err| log.warn("error stopping serial reader err=E{s}", .{@tagName(err)}),
    }
    data.read_thread.join();
}

pub fn focusGained(_: *Serial, _: *termio.Termio.ThreadData, _: bool) !void {}
pub fn resize(_: *Serial, _: renderer.GridSize, _: renderer.ScreenSize) !void {}
pub fn childExitedAbnormally(_: *Serial, _: Allocator, _: *terminal.Terminal, _: u32, _: u64) !void {}
pub fn getProcessInfo(_: *Serial, comptime info: ProcessInfo) ?ProcessInfo.Type(info) {
    return null;
}

pub fn queueWrite(_: *Serial, alloc: Allocator, td: *termio.Termio.ThreadData, data: []const u8, linefeed: bool) !void {
    const serial = &td.backend.serial;
    var offset: usize = 0;
    while (offset < data.len) {
        const write = try serial.write_pool.create(alloc);
        write.td = serial;
        const end = @min(data.len, offset + write.buf.len);
        if (!linefeed) {
            fastmem.copy(u8, &write.buf, data[offset..end]);
            write.len = end - offset;
            offset = end;
        } else {
            var n: usize = 0;
            while (offset < data.len and n < write.buf.len - 1) : (offset += 1) {
                const byte = data[offset];
                write.buf[n] = byte;
                n += 1;
                if (byte == '\r') {
                    write.buf[n] = '\n';
                    n += 1;
                }
            }
            write.len = n;
        }
        serial.write_stream.queueWrite(td.loop, &serial.write_queue, &write.req, .{ .slice = write.buf[0..write.len] }, ThreadData.Write, write, writeDone);
    }
}

pub const ThreadData = struct {
    pub const Write = struct {
        td: *ThreadData,
        req: xev.WriteRequest,
        buf: [256]u8 = undefined,
        len: usize = 0,
    };

    fd: posix.fd_t,
    write_stream: xev.Stream,
    write_pool: std.heap.MemoryPool(Write) = .empty,
    write_queue: xev.WriteQueue = .{},
    read_thread: std.Thread,
    read_thread_pipe: posix.fd_t,

    pub fn deinit(self: *ThreadData, alloc: Allocator) void {
        _ = posix.system.close(self.read_thread_pipe);
        self.write_pool.deinit(alloc);
        self.write_stream.deinit();
        _ = c.close(self.fd);
    }

    pub fn sendBreak(self: *ThreadData, duration_ms: u32) !void {
        if (c.ioctl(self.fd, c.TIOCSBRK) != 0) return error.SerialBreakFailed;
        try std.Io.sleep(global.io(), .fromMilliseconds(@max(duration_ms, 1)), .awake);
        if (c.ioctl(self.fd, c.TIOCCBRK) != 0) return error.SerialBreakFailed;
    }
};

fn writeDone(write_: ?*ThreadData.Write, _: *xev.Loop, _: *xev.Completion, _: xev.Stream, _: xev.WriteBuffer, result: xev.WriteError!usize) xev.CallbackAction {
    const write = write_.?;
    defer write.td.write_pool.destroy(write);
    _ = result catch |err| {
        log.warn("serial write failed: {}", .{err});
        return .disarm;
    };
    return .disarm;
}

fn configure(fd: c_int, config: Config) !void {
    if (config.data_bits < 5 or config.data_bits > 8) return error.UnsupportedDataBits;
    if (config.parity > 2) return error.UnsupportedParity;
    if (config.stop_bits != 1 and config.stop_bits != 2) return error.UnsupportedStopBits;
    if (config.flow_control > 2) return error.UnsupportedFlowControl;

    var options: c.struct_termios = undefined;
    if (c.tcgetattr(fd, &options) != 0) return error.SerialConfigurationFailed;
    c.cfmakeraw(&options);
    options.c_cflag |= c.CLOCAL | c.CREAD;
    options.c_cflag &= ~@as(@TypeOf(options.c_cflag), c.CSIZE);
    options.c_cflag |= switch (config.data_bits) {
        5 => c.CS5,
        6 => c.CS6,
        7 => c.CS7,
        8 => c.CS8,
        else => unreachable,
    };
    options.c_cflag &= ~@as(@TypeOf(options.c_cflag), c.PARENB | c.PARODD | c.CSTOPB | c.CRTS_IFLOW | c.CCTS_OFLOW);
    if (config.parity != 0) {
        options.c_cflag |= c.PARENB;
        if (config.parity == 1) options.c_cflag |= c.PARODD;
    }
    if (config.stop_bits == 2) options.c_cflag |= c.CSTOPB;
    options.c_iflag &= ~@as(@TypeOf(options.c_iflag), c.IXON | c.IXOFF | c.IXANY);
    switch (config.flow_control) {
        1 => options.c_cflag |= c.CRTS_IFLOW | c.CCTS_OFLOW,
        2 => options.c_iflag |= c.IXON | c.IXOFF,
        else => {},
    }
    const speed = try baud(config.baud_rate);
    if (c.cfsetispeed(&options, speed) != 0 or c.cfsetospeed(&options, speed) != 0 or c.tcsetattr(fd, c.TCSANOW, &options) != 0) return error.SerialConfigurationFailed;
}

fn baud(value: u32) !c.speed_t {
    return switch (value) {
        9_600 => c.B9600,
        19_200 => c.B19200,
        38_400 => c.B38400,
        57_600 => c.B57600,
        115_200 => c.B115200,
        230_400 => c.B230400,
        else => error.UnsupportedBaudRate,
    };
}
