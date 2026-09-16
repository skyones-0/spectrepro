pub const ext = @import("ext.zig");
const glibunix = @This();

const std = @import("std");
const compat = @import("compat");
const glib = @import("glib2");
/// A Unix pipe. The advantage of this type over `int[2]` is that it can
/// be closed automatically when it goes out of scope, using `g_auto(GUnixPipe)`,
/// on compilers that support that feature.
pub const Pipe = extern struct {
    /// A pair of file descriptors, each negative if closed or not yet opened.
    ///  The file descriptor with index `G_UNIX_PIPE_END_READ` is readable.
    ///  The file descriptor with index `G_UNIX_PIPE_END_WRITE` is writable.
    f_fds: [2]c_int,

    test {
        @setEvalBranchQuota(100_000);
        std.testing.refAllDecls(@This());
    }
};

/// Mnemonic constants for the ends of a Unix pipe.
pub const PipeEnd = enum(c_int) {
    read = 0,
    write = 1,
    _,

    test {
        @setEvalBranchQuota(100_000);
        std.testing.refAllDecls(@This());
    }
};

/// Close every file descriptor equal to or greater than `lowfd`.
///
/// Typically `lowfd` will be 3, to leave standard input, standard output
/// and standard error open.
///
/// This is the same as Linux `close_range (lowfd, ~0U, 0)`,
/// but portable to other OSs and to older versions of Linux.
/// Equivalently, it is the same as BSD `closefrom (lowfd)`, but portable,
/// and async-signal-safe on all OSs.
///
/// This function is async-signal safe, making it safe to call from a
/// signal handler or a `glib.SpawnChildSetupFunc`, as long as `lowfd` is
/// non-negative.
/// See [`signal(7)`](man:signal(7)) and
/// [`signal-safety(7)`](man:signal-safety(7)) for more details.
extern fn g_closefrom(p_lowfd: c_int) c_int;
pub const closefrom = g_closefrom;

extern fn g_unix_error_quark() glib.Quark;
pub const errorQuark = g_unix_error_quark;

/// Sets a function to be called when the IO condition, as specified by
/// `condition` becomes true for `fd`.
///
/// `function` will be called when the specified IO condition becomes
/// `TRUE`.  The function is expected to clear whatever event caused the
/// IO condition to become true and return `TRUE` in order to be notified
/// when it happens again.  If `function` returns `FALSE` then the watch
/// will be cancelled.
///
/// The return value of this function can be passed to `glib.sourceRemove`
/// to cancel the watch at any time that it exists.
///
/// The source will never close the fd -- you must do it yourself.
extern fn g_unix_fd_add(p_fd: c_int, p_condition: glib.IOCondition, p_function: glibunix.FDSourceFunc, p_user_data: ?*anyopaque) c_uint;
pub const fdAdd = g_unix_fd_add;

/// Sets a function to be called when the IO condition, as specified by
/// `condition` becomes true for `fd`.
///
/// This is the same as `glibunix.fdAdd`, except that it allows you to
/// specify a non-default priority and a provide a `glib.DestroyNotify` for
/// `user_data`.
extern fn g_unix_fd_add_full(p_priority: c_int, p_fd: c_int, p_condition: glib.IOCondition, p_function: glibunix.FDSourceFunc, p_user_data: ?*anyopaque, p_notify: ?glib.DestroyNotify) c_uint;
pub const fdAddFull = g_unix_fd_add_full;

/// Queries the file path for the given FD opened by the current process.
extern fn g_unix_fd_query_path(p_fd: c_int, p_error: ?*?*glib.Error) ?[*:0]u8;
pub const fdQueryPath = g_unix_fd_query_path;

/// Creates a `glib.Source` to watch for a particular I/O condition on a file
/// descriptor.
///
/// The source will never close the `fd` — you must do it yourself.
///
/// Any callback attached to the returned `glib.Source` must have type
/// `glibunix.FDSourceFunc`.
extern fn g_unix_fd_source_new(p_fd: c_int, p_condition: glib.IOCondition) *glib.Source;
pub const fdSourceNew = g_unix_fd_source_new;

/// Mark every file descriptor equal to or greater than `lowfd` to be closed
/// at the next ``execve`` or similar, as if via the `FD_CLOEXEC` flag.
///
/// Typically `lowfd` will be 3, to leave standard input, standard output
/// and standard error open after exec.
///
/// This is the same as Linux `close_range (lowfd, ~0U, CLOSE_RANGE_CLOEXEC)`,
/// but portable to other OSs and to older versions of Linux.
///
/// This function is async-signal safe, making it safe to call from a
/// signal handler or a `glib.SpawnChildSetupFunc`, as long as `lowfd` is
/// non-negative.
/// See [`signal(7)`](man:signal(7)) and
/// [`signal-safety(7)`](man:signal-safety(7)) for more details.
extern fn g_fdwalk_set_cloexec(p_lowfd: c_int) c_int;
pub const fdwalkSetCloexec = g_fdwalk_set_cloexec;

/// Get the `passwd` file entry for the given `user_name` using ``getpwnam_r``.
/// This can fail if the given `user_name` doesn’t exist.
///
/// The returned `struct passwd` has been allocated using `glib.malloc` and should
/// be freed using `glib.free`. The strings referenced by the returned struct are
/// included in the same allocation, so are valid until the `struct passwd` is
/// freed.
///
/// This function is safe to call from multiple threads concurrently.
///
/// You will need to include `pwd.h` to get the definition of `struct passwd`.
extern fn g_unix_get_passwd_entry(p_user_name: [*:0]const u8, p_error: ?*?*glib.Error) ?*anyopaque;
pub const getPasswdEntry = g_unix_get_passwd_entry;

/// Similar to the UNIX `pipe` call, but on modern systems like Linux
/// uses the `pipe2` system call, which atomically creates a pipe with
/// the configured flags.
///
/// As of GLib 2.78, the supported flags are `O_CLOEXEC`/`FD_CLOEXEC` (see below)
/// and `O_NONBLOCK`. Prior to GLib 2.78, only `FD_CLOEXEC` was supported — if
/// you wanted to configure `O_NONBLOCK` then that had to be done separately with
/// ``fcntl``.
///
/// Since GLib 2.80, the constants `G_UNIX_PIPE_END_READ` and
/// `G_UNIX_PIPE_END_WRITE` can be used as mnemonic indexes in `fds`.
///
/// It is a programmer error to call this function with unsupported flags, and a
/// critical warning will be raised.
///
/// As of GLib 2.78, it is preferred to pass `O_CLOEXEC` in, rather than
/// `FD_CLOEXEC`, as that matches the underlying ``pipe`` API more closely. Prior
/// to 2.78, only `FD_CLOEXEC` was supported. Support for `FD_CLOEXEC` may be
/// deprecated and removed in future.
extern fn g_unix_open_pipe(p_fds: *[2]c_int, p_flags: c_int, p_error: ?*?*glib.Error) c_int;
pub const openPipe = g_unix_open_pipe;

/// Control the non-blocking state of the given file descriptor,
/// according to `nonblock`. On most systems this uses `O_NONBLOCK`, but
/// on some older ones may use `O_NDELAY`.
extern fn g_unix_set_fd_nonblocking(p_fd: c_int, p_nonblock: c_int, p_error: ?*?*glib.Error) c_int;
pub const setFdNonblocking = g_unix_set_fd_nonblocking;

/// A convenience function for `glibunix.signalSourceNew`, which
/// attaches to the default `glib.MainContext`.  You can remove the watch
/// using `glib.sourceRemove`.
extern fn g_unix_signal_add(p_signum: c_int, p_handler: glib.SourceFunc, p_user_data: ?*anyopaque) c_uint;
pub const signalAdd = g_unix_signal_add;

/// A convenience function for `glibunix.signalSourceNew`, which
/// attaches to the default `glib.MainContext`.  You can remove the watch
/// using `glib.sourceRemove`.
extern fn g_unix_signal_add_full(p_priority: c_int, p_signum: c_int, p_handler: glib.SourceFunc, p_user_data: ?*anyopaque, p_notify: ?glib.DestroyNotify) c_uint;
pub const signalAddFull = g_unix_signal_add_full;

/// Create a `glib.Source` that will be dispatched upon delivery of the UNIX
/// signal `signum`.  In GLib versions before 2.36, only `SIGHUP`, `SIGINT`,
/// `SIGTERM` can be monitored.  In GLib 2.36, `SIGUSR1` and `SIGUSR2`
/// were added. In GLib 2.54, `SIGWINCH` was added.
///
/// Note that unlike the UNIX default, all sources which have created a
/// watch will be dispatched, regardless of which underlying thread
/// invoked `glibunix.signalSourceNew`.
///
/// For example, an effective use of this function is to handle `SIGTERM`
/// cleanly; flushing any outstanding files, and then calling
/// `glib.MainLoop.quit`.  It is not safe to do any of this from a regular
/// UNIX signal handler; such a handler may be invoked while `malloc` or
/// another library function is running, causing reentrancy issues if the
/// handler attempts to use those functions.  None of the GLib/GObject
/// API is safe against this kind of reentrancy.
///
/// The interaction of this source when combined with native UNIX
/// functions like `sigprocmask` is not defined.
///
/// The source will not initially be associated with any `glib.MainContext`
/// and must be added to one with `glib.Source.attach` before it will be
/// executed.
extern fn g_unix_signal_source_new(p_signum: c_int) *glib.Source;
pub const signalSourceNew = g_unix_signal_source_new;

/// The type of functions to be called when a UNIX fd watch source
/// triggers.
pub const FDSourceFunc = *const fn (p_fd: c_int, p_condition: glib.IOCondition, p_user_data: ?*anyopaque) callconv(.c) c_int;

test {
    @setEvalBranchQuota(100_000);
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(ext);
}
