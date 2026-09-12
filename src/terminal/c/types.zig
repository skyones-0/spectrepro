//! Comptime-generated ABI metadata for the public libspectrepro-vt C types.
//!
//! The manifest is embedded in the library and returned by
//! `spectrepro_type_json`. It is intended for FFI consumers that cannot use the
//! C headers directly, most notably WebAssembly hosts. Its format is defined
//! by `types.schema.json`.
const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("terminal_options");
const lib = @import("../lib.zig");
const c_abi = @import("../../lib/c_abi.zig");

const color = @import("../color.zig");
const clipboard = @import("../clipboard.zig");
const device_status = @import("../device_status.zig");
const focus_pkg = @import("../focus.zig");
const formatter_pkg = @import("../formatter.zig");
const modes_pkg = @import("../modes.zig");
const mouse_pkg = @import("../mouse.zig");
const page = @import("../page.zig");
const point = @import("../point.zig");
const Selection = @import("../Selection.zig");
const sgr = @import("../sgr.zig");

const input_config = @import("../../input/config.zig");
const input_key = @import("../../input/key.zig");
const input_mouse = @import("../../input/mouse.zig");

const build_info = @import("build_info.zig");
const cell = @import("cell.zig");
const color_c = @import("color.zig");
const formatter = @import("formatter.zig");
const grid_ref = @import("grid_ref.zig");
const io = @import("io.zig");
const key_encode = @import("key_encode.zig");
const kitty_graphics = @import("kitty_graphics.zig");
const mouse_encode = @import("mouse_encode.zig");
const mouse_event = @import("mouse_event.zig");
const osc = @import("osc.zig");
const paste = @import("paste.zig");
const render = @import("render.zig");
const result = @import("result.zig");
const row = @import("row.zig");
const search = @import("search.zig");
const selection = @import("selection.zig");
const selection_gesture = @import("selection_gesture.zig");
const size_report = @import("size_report.zig");
const snapshot = @import("snapshot.zig");
const style = @import("style.zig");
const sys = @import("sys.zig");
const terminal = @import("terminal.zig");

/// C: SpectreProSurfacePosition
pub const SurfacePosition = extern struct {
    x: f64,
    y: f64,
};

/// C: SpectreProCodepoints
pub const Codepoints = extern struct {
    ptr: ?[*]const u32 = null,
    len: usize = 0,
};

const TypeDecl = struct {
    name: []const u8,
    T: type,
    kind: Kind,
    prefix: []const u8 = "",
    sentinel_suffix: []const u8 = "MAX_VALUE",
    alias_type: []const u8 = "",
    tagged_union: ?TaggedUnion = null,
    union_field_names_T: ?type = null,

    const Kind = enum {
        @"struct",
        @"union",
        @"enum",
        @"packed",
        alias,
        @"opaque",
    };

    const TaggedUnion = struct {
        tag_field: []const u8,
        value_field: []const u8,
        arm_source: ArmSource,

        const ArmSource = enum {
            fields,
            generated,
        };
    };

    fn initStruct(comptime name: []const u8, comptime T: type) TypeDecl {
        return .{ .name = name, .T = T, .kind = .@"struct" };
    }

    fn initTaggedStruct(
        comptime name: []const u8,
        comptime T: type,
        comptime tag_field: []const u8,
        comptime value_field: []const u8,
        comptime arm_source: TaggedUnion.ArmSource,
    ) TypeDecl {
        return .{
            .name = name,
            .T = T,
            .kind = .@"struct",
            .tagged_union = .{
                .tag_field = tag_field,
                .value_field = value_field,
                .arm_source = arm_source,
            },
        };
    }

    fn initUnion(
        comptime name: []const u8,
        comptime T: type,
        comptime field_names_T: ?type,
    ) TypeDecl {
        return .{
            .name = name,
            .T = T,
            .kind = .@"union",
            .union_field_names_T = field_names_T,
        };
    }

    fn initEnum(
        comptime name: []const u8,
        comptime T: type,
        comptime prefix: []const u8,
    ) TypeDecl {
        return .{ .name = name, .T = T, .kind = .@"enum", .prefix = prefix };
    }

    fn initEnumSentinel(
        comptime name: []const u8,
        comptime T: type,
        comptime prefix: []const u8,
        comptime sentinel_suffix: []const u8,
    ) TypeDecl {
        return .{
            .name = name,
            .T = T,
            .kind = .@"enum",
            .prefix = prefix,
            .sentinel_suffix = sentinel_suffix,
        };
    }

    fn initPacked(comptime name: []const u8, comptime T: type) TypeDecl {
        return .{ .name = name, .T = T, .kind = .@"packed" };
    }

    fn initAlias(
        comptime name: []const u8,
        comptime T: type,
        comptime alias_type: []const u8,
    ) TypeDecl {
        return .{ .name = name, .T = T, .kind = .alias, .alias_type = alias_type };
    }

    fn initOpaque(comptime name: []const u8) TypeDecl {
        return .{ .name = name, .T = *anyopaque, .kind = .@"opaque" };
    }
};

/// Public C types. Names and enum prefixes are intentionally explicit because
/// Zig identifiers are not the C API contract.
const type_decls = [_]TypeDecl{
    .initStruct("SpectreProAllocator", lib.alloc.Allocator),
    .initStruct("SpectreProAllocatorVtable", lib.alloc.VTable),
    .initStruct("SpectreProBuffer", lib.Buffer),
    .initStruct("SpectreProCellsView", cell.CellsView),
    .initStruct("SpectreProClipboardContent", terminal.ClipboardContent),
    .initStruct("SpectreProClipboardRead", terminal.ClipboardRead),
    .initStruct("SpectreProClipboardReadReply", terminal.ClipboardReadReply),
    .initStruct("SpectreProClipboardWrite", terminal.ClipboardWrite),
    .initStruct("SpectreProClipboardWriteReply", terminal.ClipboardWriteReply),
    .initStruct("SpectreProCodepoints", Codepoints),
    .initStruct("SpectreProColorPaletteMask", color_c.PaletteMask),
    .initStruct("SpectreProColorRgb", color.RGB.C),
    .initStruct("SpectreProColorX11Entry", color_c.X11Entry),
    .initStruct("SpectreProDeviceAttributes", terminal.DeviceAttributes),
    .initStruct("SpectreProDeviceAttributesPrimary", terminal.DeviceAttributes.Primary),
    .initStruct("SpectreProDeviceAttributesSecondary", terminal.DeviceAttributes.Secondary),
    .initStruct("SpectreProDeviceAttributesTertiary", terminal.DeviceAttributes.Tertiary),
    .initStruct("SpectreProFormatterScreenExtra", formatter.ScreenOptions.Extra),
    .initStruct("SpectreProFormatterTerminalExtra", formatter.TerminalOptions.Extra),
    .initStruct("SpectreProFormatterTerminalOptions", formatter.TerminalOptions),
    .initStruct("SpectreProGridRef", grid_ref.CGridRef),
    .initStruct("SpectreProKittyGraphicsPlacementRenderInfo", kitty_graphics.PlacementRenderInfo),
    .initStruct("SpectreProMimeReader", io.MimeReader),
    .initStruct("SpectreProMouseEncoderSize", mouse_encode.Size),
    .initStruct("SpectreProMousePosition", mouse_event.Position),
    .initStruct("SpectreProPaste", paste.Request),
    .initTaggedStruct("SpectreProPoint", point.Point.C, "tag", "value", .generated),
    .initStruct("SpectreProPointCoordinate", point.Coordinate),
    .initUnion("SpectreProPointValue", point.Point.CValue, point.Point.C),
    .initStruct("SpectreProReader", io.Reader),
    .initStruct("SpectreProRenderStateColors", render.Colors),
    .initStruct("SpectreProRenderStateCursor", render.Cursor),
    .initStruct("SpectreProRenderStateRowSelection", render.RowSelection),
    .initStruct("SpectreProSelection", selection.CSelection),
    .initStruct("SpectreProSelectionBuffer", selection.CSelectionBuffer),
    .initStruct("SpectreProSelectionGestureBehaviors", selection_gesture.Behaviors),
    .initStruct("SpectreProSelectionGestureGeometry", selection_gesture.Geometry),
    .initTaggedStruct("SpectreProSgrAttribute", sgr.Attribute.C, "tag", "value", .generated),
    .initStruct("SpectreProSgrUnknown", sgr.Attribute.Unknown.C),
    .initUnion("SpectreProSgrAttributeValue", sgr.Attribute.CValue, sgr.Attribute.C),
    .initStruct("SpectreProSizeReportSize", size_report.Size),
    .initStruct("SpectreProString", lib.String),
    .initStruct("SpectreProSurfacePosition", SurfacePosition),
    .initStruct("SpectreProStyle", style.Style),
    .initTaggedStruct("SpectreProStyleColor", style.Color, "tag", "value", .fields),
    .initUnion("SpectreProStyleColorValue", style.ColorValue, null),
    .initStruct("SpectreProSysImage", sys.Image),
    .initStruct("SpectreProTerminalDesktopNotification", terminal.DesktopNotification),
    .initStruct("SpectreProTerminalModeConfig", terminal.ModeConfig),
    .initStruct("SpectreProTerminalProgressReport", terminal.ProgressReport),
    .initStruct("SpectreProTerminalScrollbar", terminal.TerminalScrollbar),
    .initTaggedStruct("SpectreProTerminalScrollViewport", terminal.ScrollViewport, "tag", "value", .generated),
    .initUnion(
        "SpectreProTerminalScrollViewportValue",
        terminal.ZigTerminal.ScrollViewport.CValue,
        terminal.ZigTerminal.ScrollViewport.C,
    ),
    .initStruct("SpectreProTerminalSelectLineOptions", selection.SelectLineOptions),
    .initStruct("SpectreProTerminalSelectWordBetweenOptions", selection.SelectWordBetweenOptions),
    .initStruct("SpectreProTerminalSelectWordOptions", selection.SelectWordOptions),
    .initStruct("SpectreProTerminalSelectionFormatOptions", selection.FormatOptions),
    .initTaggedStruct("SpectreProTerminalUnknownSequence", terminal.UnknownSequence.C, "tag", "value", .generated),
    .initStruct("SpectreProTerminalUnknownStringSequence", terminal.UnknownStringSequence),
    .initUnion(
        "SpectreProTerminalUnknownSequenceValue",
        terminal.UnknownSequence.CValue,
        terminal.UnknownSequence.C,
    ),
    .initStruct("SpectreProWriter", io.Writer),

    .initEnumSentinel("SpectreProResult", result.Result, "SPECTREPRO_", "RESULT_MAX_VALUE"),
    .initEnum("SpectreProBuildInfo", build_info.BuildInfo, "SPECTREPRO_BUILD_INFO_"),
    .initEnumSentinel("SpectreProOptimizeMode", build_info.OptimizeMode, "SPECTREPRO_OPTIMIZE_", "MODE_MAX_VALUE"),
    .initEnumSentinel("SpectreProCellContentTag", cell.ContentTag, "SPECTREPRO_CELL_CONTENT_", "TAG_MAX_VALUE"),
    .initEnum("SpectreProCellData", cell.CellData, "SPECTREPRO_CELL_DATA_"),
    .initEnum("SpectreProCellSemanticContent", cell.SemanticContent, "SPECTREPRO_CELL_SEMANTIC_"),
    .initEnum("SpectreProCellWide", cell.Wide, "SPECTREPRO_CELL_WIDE_"),
    .initEnum("SpectreProClipboardLocation", clipboard.Location, "SPECTREPRO_CLIPBOARD_LOCATION_"),
    .initEnum("SpectreProClipboardReadResult", clipboard.Read.Status, "SPECTREPRO_CLIPBOARD_READ_RESULT_"),
    .initEnum("SpectreProClipboardWriteResult", clipboard.Write.Status, "SPECTREPRO_CLIPBOARD_WRITE_RESULT_"),
    .initEnum("SpectreProColorScheme", device_status.ColorScheme, "SPECTREPRO_COLOR_SCHEME_"),
    .initEnum("SpectreProFocusEvent", focus_pkg.Event, "SPECTREPRO_FOCUS_"),
    .initEnum("SpectreProFormatterFormat", formatter_pkg.Format, "SPECTREPRO_FORMATTER_FORMAT_"),
    .initEnum("SpectreProKey", input_key.Key, "SPECTREPRO_KEY_"),
    .initEnum("SpectreProKeyAction", input_key.Action, "SPECTREPRO_KEY_ACTION_"),
    .initEnum("SpectreProKeyEncoderOption", key_encode.Option, "SPECTREPRO_KEY_ENCODER_OPT_"),
    .initEnum("SpectreProKittyGraphicsData", kitty_graphics.Data, "SPECTREPRO_KITTY_GRAPHICS_DATA_"),
    .initEnum("SpectreProKittyGraphicsImageData", kitty_graphics.ImageData, "SPECTREPRO_KITTY_IMAGE_DATA_"),
    .initEnum("SpectreProKittyGraphicsPlacementData", kitty_graphics.PlacementData, "SPECTREPRO_KITTY_GRAPHICS_PLACEMENT_DATA_"),
    .initEnum("SpectreProKittyGraphicsPlacementIteratorOption", kitty_graphics.PlacementIteratorOption, "SPECTREPRO_KITTY_GRAPHICS_PLACEMENT_ITERATOR_OPTION_"),
    .initEnum("SpectreProKittyImageCompression", kitty_graphics.ImageCompression, "SPECTREPRO_KITTY_IMAGE_COMPRESSION_"),
    .initEnum("SpectreProKittyImageFormat", kitty_graphics.ImageFormat, "SPECTREPRO_KITTY_IMAGE_FORMAT_"),
    .initEnum("SpectreProKittyPlacementLayer", kitty_graphics.PlacementLayer, "SPECTREPRO_KITTY_PLACEMENT_LAYER_"),
    .initEnum("SpectreProModeReportState", modes_pkg.Report.State, "SPECTREPRO_MODE_REPORT_"),
    .initEnum("SpectreProMouseAction", input_mouse.Action, "SPECTREPRO_MOUSE_ACTION_"),
    .initEnum("SpectreProMouseButton", input_mouse.Button, "SPECTREPRO_MOUSE_BUTTON_"),
    .initEnum("SpectreProMouseEncoderOption", mouse_encode.Option, "SPECTREPRO_MOUSE_ENCODER_OPT_"),
    .initEnum("SpectreProMouseFormat", mouse_pkg.Format, "SPECTREPRO_MOUSE_FORMAT_"),
    .initEnum("SpectreProMouseTrackingMode", mouse_pkg.Event, "SPECTREPRO_MOUSE_TRACKING_"),
    .initEnum("SpectreProOptionAsAlt", input_config.OptionAsAlt, "SPECTREPRO_OPTION_AS_ALT_"),
    .initEnum("SpectreProOscCommandData", osc.CommandData, "SPECTREPRO_OSC_DATA_"),
    .initEnumSentinel(
        "SpectreProOscCommandType",
        osc.CommandType,
        "SPECTREPRO_OSC_COMMAND_",
        "TYPE_MAX_VALUE",
    ),
    .initEnum("SpectreProPasteSource", paste.Source, "SPECTREPRO_PASTE_SOURCE_"),
    .initEnum("SpectreProPointTag", point.Tag, "SPECTREPRO_POINT_TAG_"),
    .initEnum("SpectreProRenderStateCursorVisualStyle", render.CursorVisualStyle, "SPECTREPRO_RENDER_STATE_CURSOR_VISUAL_STYLE_"),
    .initEnum("SpectreProRenderStateData", render.Data, "SPECTREPRO_RENDER_STATE_DATA_"),
    .initEnum("SpectreProRenderStateDirty", render.Dirty, "SPECTREPRO_RENDER_STATE_DIRTY_"),
    .initEnum("SpectreProRenderStateOption", render.SetOption, "SPECTREPRO_RENDER_STATE_OPTION_"),
    .initEnum("SpectreProRenderStateRowCellsData", render.RowCellsData, "SPECTREPRO_RENDER_STATE_ROW_CELLS_DATA_"),
    .initEnum("SpectreProRenderStateRowData", render.RowData, "SPECTREPRO_RENDER_STATE_ROW_DATA_"),
    .initEnum("SpectreProRenderStateRowOption", render.RowOption, "SPECTREPRO_RENDER_STATE_ROW_OPTION_"),
    .initEnum("SpectreProRowData", row.RowData, "SPECTREPRO_ROW_DATA_"),
    .initEnum("SpectreProRowSemanticPrompt", row.SemanticPrompt, "SPECTREPRO_ROW_SEMANTIC_"),
    .initEnum("SpectreProSearchData", search.Data, "SPECTREPRO_SEARCH_DATA_"),
    .initEnum("SpectreProSearchOption", search.Option, "SPECTREPRO_SEARCH_OPT_"),
    .initEnum("SpectreProSearchScroll", search.Scroll, "SPECTREPRO_SEARCH_SCROLL_"),
    .initEnum("SpectreProSearchStatus", search.Status, "SPECTREPRO_SEARCH_STATUS_"),
    .initEnum("SpectreProSelectionAdjust", Selection.Adjustment, "SPECTREPRO_SELECTION_ADJUST_"),
    .initEnum("SpectreProSelectionGestureAutoscroll", selection_gesture.Autoscroll, "SPECTREPRO_SELECTION_GESTURE_AUTOSCROLL_"),
    .initEnum("SpectreProSelectionGestureBehavior", selection_gesture.Behavior, "SPECTREPRO_SELECTION_GESTURE_BEHAVIOR_"),
    .initEnum("SpectreProSelectionGestureData", selection_gesture.Data, "SPECTREPRO_SELECTION_GESTURE_DATA_"),
    .initEnum("SpectreProSelectionGestureEventOption", selection_gesture.EventOption, "SPECTREPRO_SELECTION_GESTURE_EVENT_OPT_"),
    .initEnum("SpectreProSelectionGestureEventType", selection_gesture.EventType, "SPECTREPRO_SELECTION_GESTURE_EVENT_TYPE_"),
    .initEnum("SpectreProSelectionOrder", Selection.Order, "SPECTREPRO_SELECTION_ORDER_"),
    .initEnum("SpectreProSgrAttributeTag", sgr.Attribute.Tag, "SPECTREPRO_SGR_ATTR_"),
    .initEnum("SpectreProSgrUnderline", sgr.Attribute.Underline, "SPECTREPRO_SGR_UNDERLINE_"),
    .initEnumSentinel("SpectreProSizeReportStyle", size_report.Style, "SPECTREPRO_SIZE_REPORT_", "STYLE_MAX_VALUE"),
    .initEnum("SpectreProSnapshotDecoderData", snapshot.DecoderData, "SPECTREPRO_SNAPSHOT_DECODER_DATA_"),
    .initEnum("SpectreProSnapshotDecoderOption", snapshot.DecoderOption, "SPECTREPRO_SNAPSHOT_DECODER_OPT_"),
    .initEnumSentinel("SpectreProStyleColorTag", style.ColorTag, "SPECTREPRO_STYLE_COLOR_", "TAG_MAX_VALUE"),
    .initEnum("SpectreProSysLogLevel", sys.LogLevel, "SPECTREPRO_SYS_LOG_LEVEL_"),
    .initEnum("SpectreProSysOption", sys.Option, "SPECTREPRO_SYS_OPT_"),
    .initEnum("SpectreProTerminalCompressionMode", terminal.CompressionMode, "SPECTREPRO_TERMINAL_COMPRESSION_MODE_"),
    .initEnum("SpectreProTerminalCompressionResult", terminal.CompressionResult, "SPECTREPRO_TERMINAL_COMPRESSION_RESULT_"),
    .initEnum("SpectreProTerminalCursorStyle", terminal.TerminalCursorStyle, "SPECTREPRO_TERMINAL_CURSOR_STYLE_"),
    .initEnum("SpectreProTerminalData", terminal.TerminalData, "SPECTREPRO_TERMINAL_DATA_"),
    .initEnum("SpectreProTerminalOption", terminal.Option, "SPECTREPRO_TERMINAL_OPT_"),
    .initEnum("SpectreProTerminalProgressState", terminal.ProgressState, "SPECTREPRO_TERMINAL_PROGRESS_STATE_"),
    .initEnum("SpectreProTerminalScreen", terminal.TerminalScreen, "SPECTREPRO_TERMINAL_SCREEN_"),
    .initEnum("SpectreProTerminalScrollViewportTag", terminal.ZigTerminal.ScrollViewport.Tag, "SPECTREPRO_SCROLL_VIEWPORT_"),
    .initEnum("SpectreProTerminalUnknownSequenceTag", terminal.UnknownSequence.Tag, "SPECTREPRO_TERMINAL_UNKNOWN_SEQUENCE_"),

    .initPacked("SpectreProCell", page.Cell.CLayout),
    .initAlias("SpectreProColorPaletteIndex", u8, "u8"),
    .initAlias("SpectreProKittyKeyFlags", u8, "u8"),
    .initAlias("SpectreProMode", u16, "u16"),
    .initAlias("SpectreProMods", u16, "u16"),
    .initAlias("SpectreProRow", u64, "u64"),
    .initAlias("SpectreProStyleId", u16, "u16"),

    .initOpaque("SpectreProFormatter"),
    .initOpaque("SpectreProKeyEncoder"),
    .initOpaque("SpectreProKeyEvent"),
    .initOpaque("SpectreProKittyGraphics"),
    .initOpaque("SpectreProKittyGraphicsImage"),
    .initOpaque("SpectreProKittyGraphicsPlacementIterator"),
    .initOpaque("SpectreProMouseEncoder"),
    .initOpaque("SpectreProMouseEvent"),
    .initOpaque("SpectreProOscCommand"),
    .initOpaque("SpectreProOscParser"),
    .initOpaque("SpectreProRenderState"),
    .initOpaque("SpectreProRenderStateRowCells"),
    .initOpaque("SpectreProRenderStateRowIterator"),
    .initOpaque("SpectreProSearch"),
    .initOpaque("SpectreProSelectionGesture"),
    .initOpaque("SpectreProSelectionGestureEvent"),
    .initOpaque("SpectreProSgrParser"),
    .initOpaque("SpectreProSnapshotDecoder"),
    .initOpaque("SpectreProTerminal"),
    .initOpaque("SpectreProTrackedGridRef"),
};

comptime {
    @setEvalBranchQuota(100_000);
    for (type_decls, 0..) |decl, i| {
        for (type_decls[0..i]) |previous| {
            if (std.mem.eql(u8, decl.name, previous.name))
                @compileError("duplicate public ABI type: " ++ decl.name);
        }
    }
}

pub const json: [:0]const u8 = json: {
    @setEvalBranchQuota(1_000_000);
    var counter: std.Io.Writer.Discarding = .init(&.{});
    Json.writeAll(&counter.writer) catch unreachable;

    var buf: [counter.count:0]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buf);
    Json.writeAll(&writer) catch unreachable;
    const final = buf;
    break :json final[0..writer.end :0];
};

pub fn get_json() callconv(lib.calling_conv) [*:0]const u8 {
    return json.ptr;
}

const Json = struct {
    fn writeAll(writer: *std.Io.Writer) std.Io.Writer.Error!void {
        var jws: std.json.Stringify = .{ .writer = writer };
        try jws.beginObject();
        try jws.objectField("schema");
        try jws.write(1);

        try jws.objectField("abi");
        try jws.beginObject();
        try jws.objectField("target");
        try jws.write(@tagName(builtin.target.cpu.arch));
        try jws.objectField("os");
        try jws.write(@tagName(builtin.target.os.tag));
        try jws.objectField("environment");
        try jws.write(@tagName(builtin.target.abi));
        try jws.objectField("pointer_size");
        try jws.write(@sizeOf(*anyopaque));
        try jws.objectField("usize_size");
        try jws.write(@sizeOf(usize));
        try jws.objectField("max_alignment");
        try jws.write(c_abi.max_alignment);
        try jws.objectField("endian");
        try jws.write(@tagName(builtin.target.cpu.arch.endian()));
        try jws.endObject();

        try jws.objectField("library_version");
        try jws.write(build_options.version_string);
        try jws.objectField("commit");
        if (build_options.version_build) |commit| try jws.write(commit) else try jws.write(null);
        try jws.objectField("dirty");
        try jws.write(null);

        try jws.objectField("types");
        try jws.beginObject();
        inline for (type_decls) |decl| {
            try jws.objectField(decl.name);
            try writeType(decl, &jws);
        }
        try jws.endObject();
        try jws.endObject();
    }

    fn writeType(comptime decl: TypeDecl, jws: *std.json.Stringify) std.Io.Writer.Error!void {
        try jws.beginObject();
        try jws.objectField("kind");
        try jws.write(@tagName(decl.kind));

        switch (decl.kind) {
            .@"struct", .@"union" => {
                try writeSizeAlign(decl.T, jws);
                try jws.objectField("fields");
                try jws.beginObject();
                if (decl.union_field_names_T != null) {
                    try writeMappedUnionFields(decl, jws);
                } else {
                    const fields = switch (decl.kind) {
                        .@"struct" => @typeInfo(decl.T).@"struct".fields,
                        .@"union" => @typeInfo(decl.T).@"union".fields,
                        else => unreachable,
                    };
                    inline for (fields) |field| {
                        try writeField(
                            decl,
                            field.name,
                            field.type,
                            if (decl.kind == .@"union") 0 else @offsetOf(decl.T, field.name),
                            jws,
                        );
                    }
                }
                try jws.endObject();
            },
            .@"enum" => {
                try writeSizeAlign(c_int, jws);
                try jws.objectField("underlying");
                try jws.write("i32");
                try jws.objectField("prefix");
                try jws.write(decl.prefix);
                try jws.objectField("values");
                try jws.beginObject();
                inline for (@typeInfo(decl.T).@"enum".fields) |field| {
                    try writeEnumObjectField(decl.name, field.name, jws);
                    try jws.write(field.value);
                }
                try jws.objectField(decl.sentinel_suffix);
                try jws.write(std.math.maxInt(c_int));
                try jws.endObject();
            },
            .@"packed" => try writePackedType(decl.T, jws),
            .alias => {
                try writeSizeAlign(decl.T, jws);
                try jws.objectField("type");
                try jws.write(decl.alias_type);
            },
            .@"opaque" => try writeSizeAlign(*anyopaque, jws),
        }
        try jws.endObject();
    }

    fn writePackedType(
        comptime Layout: type,
        jws: *std.json.Stringify,
    ) std.Io.Writer.Error!void {
        try writeSizeAlign(Layout.Zig, jws);
        try jws.objectField("underlying");
        try jws.write(publicTypeName(Layout.Backing));
        try jws.objectField("bits");
        try jws.beginObject();
        try writePackedBits(Layout, jws);
        try jws.endObject();
    }

    fn writePackedBits(
        comptime Layout: type,
        jws: *std.json.Stringify,
    ) std.Io.Writer.Error!void {
        inline for (@typeInfo(Layout.Zig).@"struct".fields) |field| {
            const field_tag = @field(Layout.Field, field.name);
            const name = comptime Layout.fieldName(field_tag) orelse continue;
            const options = Layout.fieldOptions(field_tag);

            try jws.objectField(name);
            try jws.beginObject();
            try jws.objectField("lsb");
            try jws.write(Layout.bitOffset(field_tag));
            try jws.objectField("width");
            try jws.write(Layout.bitWidth(field_tag));

            switch (options.encoding) {
                .scalar => {
                    try jws.objectField("type");
                    try jws.write(options.type_name orelse publicTypeName(field.type));
                },
                .@"packed" => |Nested| {
                    try jws.objectField("kind");
                    try jws.write("packed");
                    try jws.objectField("bits");
                    try jws.beginObject();
                    try writePackedBits(Nested, jws);
                    try jws.endObject();
                },
                .tagged_union => |UnionLayout| try writePackedTaggedUnion(Layout, UnionLayout, jws),
            }
            try jws.endObject();
        }
    }

    fn writePackedTaggedUnion(
        comptime Layout: type,
        comptime UnionLayout: type,
        jws: *std.json.Stringify,
    ) std.Io.Writer.Error!void {
        try jws.objectField("kind");
        try jws.write("union");
        try jws.objectField("tag");
        try jws.write(Layout.fieldName(UnionLayout.tag_field).?);
        try jws.objectField("arms");
        try jws.beginObject();

        const tag_options = Layout.fieldOptions(UnionLayout.tag_field);
        const tag_type_name = tag_options.type_name orelse publicTypeName(UnionLayout.Tag);
        inline for (@typeInfo(UnionLayout.Tag).@"enum".fields) |tag| {
            try writeEnumObjectField(tag_type_name, tag.name, jws);
            const arm = UnionLayout.arm(@field(UnionLayout.Tag, tag.name)) orelse {
                try jws.write(null);
                continue;
            };
            switch (arm) {
                inline else => |ArmLayout| try writePackedArm(ArmLayout, jws),
            }
        }

        try jws.endObject();
    }

    fn writePackedArm(
        comptime Layout: type,
        jws: *std.json.Stringify,
    ) std.Io.Writer.Error!void {
        try jws.beginObject();
        try jws.objectField("kind");
        try jws.write("packed");
        try jws.objectField("width");
        try jws.write(@bitSizeOf(Layout.Zig));
        try jws.objectField("bits");
        try jws.beginObject();
        try writePackedBits(Layout, jws);
        try jws.endObject();
        try jws.endObject();
    }

    fn writeField(
        comptime decl: TypeDecl,
        comptime name: []const u8,
        comptime T: type,
        comptime offset: usize,
        jws: *std.json.Stringify,
    ) std.Io.Writer.Error!void {
        try jws.objectField(name);
        try jws.beginObject();
        try jws.objectField("offset");
        try jws.write(offset);
        try jws.objectField("size");
        try jws.write(@sizeOf(T));
        try writeFieldType(decl.name, name, T, jws);
        if (decl.tagged_union) |tagged| {
            if (std.mem.eql(u8, name, tagged.value_field)) {
                try jws.objectField("tag");
                try jws.write(tagged.tag_field);
                try writeTaggedArms(decl, tagged, jws);
            }
        }
        try jws.endObject();
    }

    fn writeMappedUnionFields(
        comptime decl: TypeDecl,
        jws: *std.json.Stringify,
    ) std.Io.Writer.Error!void {
        const FieldNames = decl.union_field_names_T.?;
        const Tag = @FieldType(FieldNames, "tag");
        const tag_fields = @typeInfo(Tag).@"enum".fields;

        inline for (tag_fields, 0..) |field, i| {
            const name = comptime FieldNames.cFieldRename(@field(Tag, field.name)) orelse continue;
            if (comptime mappedUnionFieldIsDuplicate(decl, i, name)) continue;
            try writeField(decl, name, @FieldType(decl.T, field.name), 0, jws);
        }

        if (@hasField(decl.T, "_padding"))
            try writeField(decl, "_padding", @FieldType(decl.T, "_padding"), 0, jws);
    }

    fn mappedUnionFieldIsDuplicate(
        comptime decl: TypeDecl,
        comptime index: usize,
        comptime name: []const u8,
    ) bool {
        const FieldNames = decl.union_field_names_T.?;
        const Tag = @FieldType(FieldNames, "tag");
        const tag_fields = @typeInfo(Tag).@"enum".fields;
        const T = @FieldType(decl.T, tag_fields[index].name);

        inline for (tag_fields[0..index]) |previous| {
            const previous_name = FieldNames.cFieldRename(@field(Tag, previous.name)) orelse continue;
            if (std.mem.eql(u8, previous_name, name)) {
                if (@FieldType(decl.T, previous.name) != T)
                    @compileError("tagged union metadata maps different field types to " ++ name);
                return true;
            }
        }

        return false;
    }

    fn writeSizeAlign(comptime T: type, jws: *std.json.Stringify) std.Io.Writer.Error!void {
        try jws.objectField("size");
        try jws.write(@sizeOf(T));
        try jws.objectField("align");
        try jws.write(@alignOf(T));
    }

    fn writeFieldType(
        comptime owner: []const u8,
        comptime field_name: []const u8,
        comptime T: type,
        jws: *std.json.Stringify,
    ) std.Io.Writer.Error!void {
        if (comptime std.mem.eql(u8, owner, "SpectreProCellsView") and
            std.mem.eql(u8, field_name, "ptr"))
        {
            try writePointerTypeNamed(T, true, "SpectreProCell", jws);
            return;
        }
        if (comptime std.mem.eql(u8, owner, "SpectreProGridRef") and
            std.mem.eql(u8, field_name, "node"))
        {
            try writePointerTypeNamed(T, true, "opaque", jws);
            return;
        }

        if (comptime fieldTypeOverride(owner, field_name)) |name| {
            try jws.objectField("type");
            try jws.write(name);
            return;
        }

        switch (@typeInfo(T)) {
            .array => |info| {
                try jws.objectField("type");
                try jws.write("array");
                try jws.objectField("elem");
                try jws.write(publicTypeName(info.child));
                try jws.objectField("count");
                try jws.write(info.len);
            },
            .optional => |info| try writePointerType(info.child, true, jws),
            .pointer => try writePointerType(T, false, jws),
            else => {
                try jws.objectField("type");
                try jws.write(publicTypeName(T));
            },
        }
    }

    fn writePointerType(
        comptime T: type,
        comptime nullable: bool,
        jws: *std.json.Stringify,
    ) std.Io.Writer.Error!void {
        const info = @typeInfo(T).pointer;
        try jws.objectField("type");
        try jws.write("pointer");
        try jws.objectField("elem");
        try jws.write(publicTypeName(info.child));
        try jws.objectField("const");
        try jws.write(info.is_const);
        if (nullable) {
            try jws.objectField("nullable");
            try jws.write(true);
        }
    }

    fn writePointerTypeNamed(
        comptime T: type,
        comptime nullable: bool,
        comptime elem: []const u8,
        jws: *std.json.Stringify,
    ) std.Io.Writer.Error!void {
        const pointer_type = switch (@typeInfo(T)) {
            .optional => |info| info.child,
            .pointer => T,
            else => unreachable,
        };
        const info = @typeInfo(pointer_type).pointer;
        try jws.objectField("type");
        try jws.write("pointer");
        try jws.objectField("elem");
        try jws.write(elem);
        try jws.objectField("const");
        try jws.write(info.is_const);
        if (nullable) {
            try jws.objectField("nullable");
            try jws.write(true);
        }
    }

    fn fieldTypeOverride(comptime owner: []const u8, comptime field_name: []const u8) ?[]const u8 {
        if (std.mem.eql(u8, field_name, "value")) {
            if (std.mem.eql(u8, owner, "SpectreProPoint")) return "SpectreProPointValue";
            if (std.mem.eql(u8, owner, "SpectreProSgrAttribute")) return "SpectreProSgrAttributeValue";
            if (std.mem.eql(u8, owner, "SpectreProStyleColor")) return "SpectreProStyleColorValue";
            if (std.mem.eql(u8, owner, "SpectreProTerminalScrollViewport")) return "SpectreProTerminalScrollViewportValue";
            if (std.mem.eql(u8, owner, "SpectreProTerminalUnknownSequence")) return "SpectreProTerminalUnknownSequenceValue";
        }
        if (std.mem.eql(u8, owner, "SpectreProStyleColorValue") and std.mem.eql(u8, field_name, "palette"))
            return "SpectreProColorPaletteIndex";
        if (std.mem.eql(u8, owner, "SpectreProSgrAttributeValue")) {
            if (std.mem.eql(u8, field_name, "underline")) return "SpectreProSgrUnderline";
            if (std.mem.endsWith(u8, field_name, "_8") or std.mem.endsWith(u8, field_name, "_256"))
                return "SpectreProColorPaletteIndex";
        }
        if (std.mem.eql(u8, owner, "SpectreProTerminalModeConfig") and std.mem.eql(u8, field_name, "mode"))
            return "SpectreProMode";
        return null;
    }

    fn writeTaggedArms(
        comptime decl: TypeDecl,
        comptime tagged: TypeDecl.TaggedUnion,
        jws: *std.json.Stringify,
    ) std.Io.Writer.Error!void {
        const Tag = @FieldType(decl.T, tagged.tag_field);
        try jws.objectField("arms");
        try jws.beginObject();
        inline for (@typeInfo(Tag).@"enum".fields) |field| {
            try writeEnumObjectField(publicTypeName(Tag), field.name, jws);
            if (comptime taggedArm(decl, field.name)) |arm| try jws.write(arm) else try jws.write(null);
        }
        try jws.endObject();
    }

    fn taggedArm(comptime decl: TypeDecl, comptime tag_name: []const u8) ?[]const u8 {
        const tagged = decl.tagged_union.?;
        const Tag = @FieldType(decl.T, tagged.tag_field);
        if (tagged.arm_source == .generated)
            return decl.T.cFieldRename(@field(Tag, tag_name));

        const Value = @FieldType(decl.T, tagged.value_field);
        if (!@hasField(Value, tag_name)) return null;
        return if (@sizeOf(@FieldType(Value, tag_name)) == 0) null else tag_name;
    }

    fn publicTypeName(comptime T: type) []const u8 {
        inline for (type_decls) |decl| switch (decl.kind) {
            .@"struct", .@"union", .@"enum" => if (T == decl.T) return decl.name,
            .@"packed", .alias, .@"opaque" => {},
        };
        return switch (@typeInfo(T)) {
            .bool => "bool",
            .float => |info| switch (info.bits) {
                32 => "f32",
                64 => "f64",
                else => "opaque",
            },
            .int => |info| intName(info.signedness, info.bits),
            .comptime_int => "comptime_int",
            .void => "void",
            .@"opaque" => "opaque",
            .@"fn" => "function",
            .@"enum" => "enum",
            .@"struct" => "struct",
            .@"union" => "union",
            else => "opaque",
        };
    }

    fn intName(comptime signedness: std.builtin.Signedness, comptime bits: u16) []const u8 {
        return switch (signedness) {
            .signed => switch (bits) {
                8 => "i8",
                16 => "i16",
                32 => "i32",
                64 => "i64",
                else => std.fmt.comptimePrint("i{d}", .{bits}),
            },
            .unsigned => switch (bits) {
                8 => "u8",
                16 => "u16",
                32 => "u32",
                64 => "u64",
                else => std.fmt.comptimePrint("u{d}", .{bits}),
            },
        };
    }

    fn writeUpperObjectField(comptime name: []const u8, jws: *std.json.Stringify) std.Io.Writer.Error!void {
        var upper: [name.len]u8 = undefined;
        for (name, 0..) |c, i| upper[i] = std.ascii.toUpper(c);
        try jws.objectField(&upper);
    }

    fn writeEnumObjectField(
        comptime enum_name: []const u8,
        comptime zig_name: []const u8,
        jws: *std.json.Stringify,
    ) std.Io.Writer.Error!void {
        if (std.mem.eql(u8, enum_name, "SpectreProKey") and std.mem.startsWith(u8, zig_name, "key_"))
            return writeUpperObjectField(zig_name["key_".len..], jws);
        if (std.mem.eql(u8, enum_name, "SpectreProSgrAttributeTag")) {
            if (std.mem.eql(u8, zig_name, "256_underline_color")) return jws.objectField("UNDERLINE_COLOR_256");
            if (std.mem.eql(u8, zig_name, "8_bg")) return jws.objectField("BG_8");
            if (std.mem.eql(u8, zig_name, "8_fg")) return jws.objectField("FG_8");
            if (std.mem.eql(u8, zig_name, "8_bright_bg")) return jws.objectField("BRIGHT_BG_8");
            if (std.mem.eql(u8, zig_name, "8_bright_fg")) return jws.objectField("BRIGHT_FG_8");
            if (std.mem.eql(u8, zig_name, "256_bg")) return jws.objectField("BG_256");
            if (std.mem.eql(u8, zig_name, "256_fg")) return jws.objectField("FG_256");
        }
        if (std.mem.eql(u8, enum_name, "SpectreProTerminalOption") and std.mem.eql(u8, zig_name, "size_cb"))
            return jws.objectField("SIZE");
        return writeUpperObjectField(zig_name, jws);
    }

    fn isBuiltinType(name: []const u8) bool {
        const builtins = [_][]const u8{
            "array", "bool",   "f32",     "f64", "function", "i8",  "i16", "i32",
            "i64",   "opaque", "pointer", "u8",  "u16",      "u32", "u64", "void",
        };
        for (builtins) |builtin_name| {
            if (std.mem.eql(u8, name, builtin_name)) return true;
        }
        if (name.len > 1 and (name[0] == 'i' or name[0] == 'u') and
            name[1] >= '1' and name[1] <= '9')
        {
            for (name[2..]) |c| if (!std.ascii.isDigit(c)) return false;
            return true;
        }
        return false;
    }
};

test "manifest parses and is versioned" {
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{});
    defer parsed.deinit();
    const root = parsed.value.object;
    try std.testing.expectEqual(@as(i64, 1), root.get("schema").?.integer);
    try std.testing.expect(root.contains("abi"));
    try std.testing.expectEqual(
        @as(i64, c_abi.max_alignment),
        root.get("abi").?.object.get("max_alignment").?.integer,
    );
    try std.testing.expect(root.contains("library_version"));
    const manifest_types = root.get("types").?.object;
    try std.testing.expectEqual(type_decls.len, manifest_types.count());
    inline for (type_decls) |decl| try std.testing.expect(manifest_types.contains(decl.name));

    const cursor_fields = manifest_types.get("SpectreProRenderStateCursor").?.object
        .get("fields").?.object;
    try std.testing.expect(cursor_fields.contains("size"));
    try std.testing.expect(cursor_fields.contains("viewport_has_value"));
    try std.testing.expect(cursor_fields.contains("viewport_x"));
    try std.testing.expect(cursor_fields.contains("viewport_y"));
    try std.testing.expect(cursor_fields.contains("wide_tail"));
    try std.testing.expect(cursor_fields.contains("visible"));
    try std.testing.expect(cursor_fields.contains("blinking"));
    try std.testing.expect(cursor_fields.contains("password_input"));
    try std.testing.expect(cursor_fields.contains("visual_style"));
}

test "manifest describes enums, arrays, and tagged unions" {
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{});
    defer parsed.deinit();
    const manifest_types = parsed.value.object.get("types").?.object;

    const data = manifest_types.get("SpectreProRenderStateData").?.object;
    try std.testing.expectEqualStrings("enum", data.get("kind").?.string);
    try std.testing.expectEqual(@as(i64, @intFromEnum(render.Data.dirty)), data.get("values").?.object.get("DIRTY").?.integer);

    const colors = manifest_types.get("SpectreProRenderStateColors").?.object;
    const palette = colors.get("fields").?.object.get("palette").?.object;
    try std.testing.expectEqualStrings("array", palette.get("type").?.string);
    try std.testing.expectEqualStrings("SpectreProColorRgb", palette.get("elem").?.string);
    try std.testing.expectEqual(@as(i64, 256), palette.get("count").?.integer);

    const style_color = manifest_types.get("SpectreProStyleColor").?.object;
    const value = style_color.get("fields").?.object.get("value").?.object;
    try std.testing.expectEqualStrings("SpectreProStyleColorValue", value.get("type").?.string);
    try std.testing.expectEqualStrings("tag", value.get("tag").?.string);
    try std.testing.expectEqualStrings("palette", value.get("arms").?.object.get("PALETTE").?.string);
    try std.testing.expect(value.get("arms").?.object.get("NONE").? == .null);
}

test "manifest describes the complete packed cell layout" {
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{});
    defer parsed.deinit();
    const manifest_types = parsed.value.object.get("types").?.object;
    const descriptor = manifest_types.get("SpectreProCell").?.object;

    try std.testing.expectEqualStrings("packed", descriptor.get("kind").?.string);
    try std.testing.expectEqual(@as(i64, @sizeOf(page.Cell.CLayout.Zig)), descriptor.get("size").?.integer);
    try std.testing.expectEqualStrings("u64", descriptor.get("underlying").?.string);

    const bits = descriptor.get("bits").?.object;
    inline for (@typeInfo(page.Cell.CLayout.Zig).@"struct".fields) |field| {
        const field_tag = @field(page.Cell.CLayout.Field, field.name);
        const name = comptime page.Cell.CLayout.fieldName(field_tag);
        if (name) |public_name| {
            const bit = bits.get(public_name).?.object;
            try std.testing.expectEqual(
                @as(i64, @intCast(@bitOffsetOf(page.Cell.CLayout.Zig, field.name))),
                bit.get("lsb").?.integer,
            );
            try std.testing.expectEqual(
                @as(i64, @intCast(@bitSizeOf(field.type))),
                bit.get("width").?.integer,
            );
        } else {
            try std.testing.expect(!bits.contains(field.name));
        }
    }

    const content = bits.get("content").?.object;
    try std.testing.expectEqualStrings("union", content.get("kind").?.string);
    try std.testing.expectEqualStrings("content_tag", content.get("tag").?.string);
    const arms = content.get("arms").?.object;

    const Content = @FieldType(page.Cell.CLayout.Zig, "content");
    const Codepoint = @FieldType(Content, "codepoint");
    const codepoint = arms.get("CODEPOINT").?.object;
    const grapheme = arms.get("CODEPOINT_GRAPHEME").?.object;
    try expectPackedArmField(codepoint, "codepoint", Codepoint, "data", "u21");
    try expectPackedArmField(grapheme, "codepoint", Codepoint, "data", "u21");
    try expectPackedArmField(
        arms.get("BG_COLOR_PALETTE").?.object,
        "index",
        @FieldType(Content, "color_palette"),
        "data",
        "SpectreProColorPaletteIndex",
    );

    const rgb = arms.get("BG_COLOR_RGB").?.object;
    const Rgb = @FieldType(Content, "color_rgb");
    inline for (@typeInfo(Rgb).@"struct".fields) |field|
        try expectPackedArmField(rgb, field.name, Rgb, field.name, "u8");
}

test "manifest packed cell layouts decode real values" {
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{});
    defer parsed.deinit();
    const manifest_types = parsed.value.object.get("types").?.object;
    const cell_bits = manifest_types.get("SpectreProCell").?.object.get("bits").?.object;

    var codepoint = page.Cell.CLayout.Zig.init('A');
    try expectDecodedCellContent(manifest_types, cell_bits, @bitCast(codepoint), "codepoint", 'A');

    codepoint.content_tag = .codepoint_grapheme;
    try expectDecodedCellContent(manifest_types, cell_bits, @bitCast(codepoint), "codepoint", 'A');

    var palette: page.Cell.CLayout.Zig = @bitCast(@as(u64, 0));
    palette.content_tag = .bg_color_palette;
    palette.content = .{ .color_palette = .{ .data = 173 } };
    try expectDecodedCellContent(manifest_types, cell_bits, @bitCast(palette), "index", 173);

    var rgb: page.Cell.CLayout.Zig = @bitCast(@as(u64, 0));
    rgb.content_tag = .bg_color_rgb;
    rgb.content = .{ .color_rgb = .{ .r = 0x12, .g = 0x34, .b = 0x56 } };
    const rgb_arm = activeCellContentArm(manifest_types, cell_bits, @bitCast(rgb));
    const content = extractManifestBits(@bitCast(rgb), cell_bits.get("content").?.object);
    try std.testing.expectEqual(@as(u64, 0x12), extractManifestBits(content, rgb_arm.get("bits").?.object.get("r").?.object));
    try std.testing.expectEqual(@as(u64, 0x34), extractManifestBits(content, rgb_arm.get("bits").?.object.get("g").?.object));
    try std.testing.expectEqual(@as(u64, 0x56), extractManifestBits(content, rgb_arm.get("bits").?.object.get("b").?.object));
}

test "manifest uses public enum names" {
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{});
    defer parsed.deinit();
    const manifest_types = parsed.value.object.get("types").?.object;

    const cell_content = manifest_types.get("SpectreProCellContentTag").?.object.get("values").?.object;
    try std.testing.expect(cell_content.contains("TAG_MAX_VALUE"));
    try std.testing.expect(!cell_content.contains("MAX_VALUE"));

    const sgr_values = manifest_types.get("SpectreProSgrAttributeTag").?.object.get("values").?.object;
    try std.testing.expectEqual(@as(i64, 9), sgr_values.get("UNDERLINE_COLOR_256").?.integer);
    try std.testing.expectEqual(@as(i64, 23), sgr_values.get("BG_8").?.integer);
    try std.testing.expect(!sgr_values.contains("256_UNDERLINE_COLOR"));

    const sgr_arms = manifest_types.get("SpectreProSgrAttribute").?.object
        .get("fields").?.object.get("value").?.object.get("arms").?.object;
    try std.testing.expectEqualStrings("underline_color_256", sgr_arms.get("UNDERLINE_COLOR_256").?.string);
    try std.testing.expectEqualStrings("bg_8", sgr_arms.get("BG_8").?.string);

    const terminal_values = manifest_types.get("SpectreProTerminalOption").?.object.get("values").?.object;
    try std.testing.expectEqual(@as(i64, 6), terminal_values.get("SIZE").?.integer);
    try std.testing.expect(!terminal_values.contains("SIZE_CB"));

    const osc_values = manifest_types.get("SpectreProOscCommandType").?.object.get("values").?.object;
    try std.testing.expectEqual(@as(i64, 22), osc_values.get("KITTY_TEXT_SIZING").?.integer);
    try std.testing.expectEqual(@as(i64, 23), osc_values.get("KITTY_CLIPBOARD_PROTOCOL").?.integer);
    try std.testing.expectEqual(@as(i64, 24), osc_values.get("KITTY_DND_PROTOCOL").?.integer);
    try std.testing.expectEqual(@as(i64, 25), osc_values.get("CONTEXT_SIGNAL").?.integer);
    try std.testing.expectEqual(@as(i64, 26), osc_values.get("KITTY_DESKTOP_NOTIFICATION").?.integer);
    try std.testing.expect(osc_values.contains("TYPE_MAX_VALUE"));
    try std.testing.expect(!osc_values.contains("MAX_VALUE"));

    const key_values = manifest_types.get("SpectreProKey").?.object.get("values").?.object;
    try std.testing.expect(key_values.contains("A"));
    try std.testing.expect(!key_values.contains("KEY_A"));

    const mode_values = manifest_types.get("SpectreProModeReportState").?.object.get("values").?.object;
    try std.testing.expectEqual(@as(i64, 0), mode_values.get("NOT_RECOGNIZED").?.integer);
    try std.testing.expectEqual(@as(i64, 4), mode_values.get("PERMANENTLY_RESET").?.integer);
}

test "manifest named references resolve" {
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{});
    defer parsed.deinit();
    const manifest_types = parsed.value.object.get("types").?.object;

    var type_iterator = manifest_types.iterator();
    while (type_iterator.next()) |type_entry| {
        const descriptor = type_entry.value_ptr.object;
        if (descriptor.get("bits")) |bits_value| {
            try expectManifestBitsValid(
                manifest_types,
                bits_value.object,
                @intCast(descriptor.get("size").?.integer * 8),
            );
        }
        const fields_value = descriptor.get("fields") orelse continue;
        var field_iterator = fields_value.object.iterator();
        while (field_iterator.next()) |field_entry| {
            const field = field_entry.value_ptr.object;
            const field_type = field.get("type").?.string;
            if (!Json.isBuiltinType(field_type))
                try std.testing.expect(manifest_types.contains(field_type));

            if (field.get("elem")) |elem_value| {
                const elem = elem_value.string;
                if (!Json.isBuiltinType(elem))
                    try std.testing.expect(manifest_types.contains(elem));
            }

            if (field.get("arms")) |arms_value| {
                const union_descriptor = manifest_types.get(field_type).?.object;
                const union_fields = union_descriptor.get("fields").?.object;
                const tag_field_name = field.get("tag").?.string;
                const tag_type_name = fields_value.object.get(tag_field_name).?.object.get("type").?.string;
                const tag_values = manifest_types.get(tag_type_name).?.object.get("values").?.object;
                var arm_iterator = arms_value.object.iterator();
                while (arm_iterator.next()) |arm_entry| {
                    try std.testing.expect(tag_values.contains(arm_entry.key_ptr.*));
                    if (arm_entry.value_ptr.* == .null) continue;
                    try std.testing.expect(union_fields.contains(arm_entry.value_ptr.string));
                }
            }
        }
    }
}

fn expectPackedArmField(
    arm: std.json.ObjectMap,
    manifest_name: []const u8,
    comptime T: type,
    comptime zig_name: []const u8,
    expected_type: []const u8,
) !void {
    try std.testing.expectEqualStrings("packed", arm.get("kind").?.string);
    try std.testing.expectEqual(@as(i64, @bitSizeOf(T)), arm.get("width").?.integer);
    const bit = arm.get("bits").?.object.get(manifest_name).?.object;
    try std.testing.expectEqual(@as(i64, @bitOffsetOf(T, zig_name)), bit.get("lsb").?.integer);
    try std.testing.expectEqual(@as(i64, @bitSizeOf(@FieldType(T, zig_name))), bit.get("width").?.integer);
    try std.testing.expectEqualStrings(expected_type, bit.get("type").?.string);
}

fn extractManifestBits(value: u64, bit: std.json.ObjectMap) u64 {
    const lsb: u6 = @intCast(bit.get("lsb").?.integer);
    const width: u7 = @intCast(bit.get("width").?.integer);
    const mask = if (width == 64)
        std.math.maxInt(u64)
    else
        (@as(u64, 1) << @intCast(width)) - 1;
    return (value >> lsb) & mask;
}

fn activeCellContentArm(
    manifest_types: std.json.ObjectMap,
    cell_bits: std.json.ObjectMap,
    raw: u64,
) std.json.ObjectMap {
    const content_tag = cell_bits.get("content_tag").?.object;
    const value = extractManifestBits(raw, content_tag);
    const enum_values = manifest_types.get(content_tag.get("type").?.string).?.object
        .get("values").?.object;
    var iterator = enum_values.iterator();
    while (iterator.next()) |entry| {
        if (entry.value_ptr.integer == value)
            return cell_bits.get("content").?.object.get("arms").?.object
                .get(entry.key_ptr.*).?.object;
    }
    unreachable;
}

fn expectDecodedCellContent(
    manifest_types: std.json.ObjectMap,
    cell_bits: std.json.ObjectMap,
    raw: u64,
    field_name: []const u8,
    expected: u64,
) !void {
    const arm = activeCellContentArm(manifest_types, cell_bits, raw);
    const content = extractManifestBits(raw, cell_bits.get("content").?.object);
    try std.testing.expectEqual(
        expected,
        extractManifestBits(content, arm.get("bits").?.object.get(field_name).?.object),
    );
}

fn expectManifestBitsValid(
    manifest_types: std.json.ObjectMap,
    bits: std.json.ObjectMap,
    container_width: usize,
) !void {
    var iterator = bits.iterator();
    while (iterator.next()) |entry| {
        const bit = entry.value_ptr.object;
        const lsb: usize = @intCast(bit.get("lsb").?.integer);
        const width: usize = @intCast(bit.get("width").?.integer);
        try std.testing.expect(lsb + width <= container_width);

        if (bit.get("type")) |type_value| {
            const type_name = type_value.string;
            try std.testing.expect(Json.isBuiltinType(type_name) or manifest_types.contains(type_name));
            continue;
        }

        const kind = bit.get("kind").?.string;
        if (std.mem.eql(u8, kind, "packed")) {
            try expectManifestBitsValid(manifest_types, bit.get("bits").?.object, width);
            continue;
        }

        try std.testing.expectEqualStrings("union", kind);
        const tag_name = bit.get("tag").?.string;
        const tag = bits.get(tag_name).?.object;
        const enum_values = manifest_types.get(tag.get("type").?.string).?.object
            .get("values").?.object;
        var arm_iterator = bit.get("arms").?.object.iterator();
        while (arm_iterator.next()) |arm_entry| {
            try std.testing.expect(enum_values.contains(arm_entry.key_ptr.*));
            if (arm_entry.value_ptr.* == .null) continue;
            const arm = arm_entry.value_ptr.object;
            const arm_width: usize = @intCast(arm.get("width").?.integer);
            try std.testing.expect(arm_width <= width);
            try expectManifestBitsValid(manifest_types, arm.get("bits").?.object, arm_width);
        }
    }
}
