//! This is the public API of the spectrepro-vt Zig module.
//!
//! WARNING: The API is not guaranteed to be stable.
//!
//! The functionality is extremely stable, since it is extracted
//! directly from SpectrePro which has been used in real world scenarios
//! by thousands of users for years. However, the API itself (functions,
//! types, etc.) may change without warning. We're working on stabilizing
//! this in the future.
const lib = @This();

const std = @import("std");
const builtin = @import("builtin");
const stderr = @import("os/stderr.zig");

// The public API below reproduces a lot of terminal/main.zig but
// is separate because (1) we need our root file to be in `src/`
// so we can access other directories and (2) we may want to withhold
// parts of `terminal` that are not ready for public consumption
// or are too SpectrePro-internal.
const terminal = @import("terminal/main.zig");

/// System interface for the terminal package.
///
/// This module provides runtime-swappable function pointers for operations
/// that depend on external implementations. Embedders can use this to
/// provide or override default behaviors. These must be set at startup
/// before any terminal functionality is used.
///
/// This lets libspectrepro-vt have no runtime dependencies on external
/// libraries, while still allowing rich functionality that may require
/// external libraries (e.g. image decoding or regular expresssions).
///
/// Setting these will enable various features of the terminal package.
/// For example, setting a PNG decoder will enable support for PNG images in
/// the Kitty Graphics Protocol.
///
/// Additional functionality will be added here over time as needed.
pub const sys = terminal.sys;

/// A tiny, blocking `std.Io` implementation optimized for binary size.
///
/// Constructing a `Terminal` requires a `std.Io` for features that touch
/// the filesystem (e.g. Kitty graphics file transmission). Embedders that
/// don't have their own `Io` can use `TinyIo` (e.g.
/// `(TinyIo.init).io()`) instead of `std.Io.Threaded` to avoid linking
/// Threaded's full vtable (networking, process spawning, async
/// machinery, etc.), which is worth roughly 110KB of binary size on
/// macOS and 370KB on Windows. See the TinyIo docs for the exact
/// tradeoffs.
pub const TinyIo = @import("lib/TinyIo.zig");

pub const apc = terminal.apc;
pub const clipboard = terminal.clipboard;
pub const dcs = terminal.dcs;
pub const osc = terminal.osc;
pub const point = terminal.point;
pub const color = terminal.color;
pub const device_status = terminal.device_status;
pub const formatter = terminal.formatter;
pub const highlight = terminal.highlight;
pub const kitty = terminal.kitty;
pub const modes = terminal.modes;
pub const page = terminal.page;
pub const parse_table = terminal.parse_table;
pub const search = terminal.search;
pub const sgr = terminal.sgr;
pub const size = terminal.size;
pub const snapshot = terminal.snapshot;
pub const x11_color = terminal.x11_color;

pub const Charset = terminal.Charset;
pub const CharsetSlot = terminal.CharsetSlot;
pub const CharsetActiveSlot = terminal.CharsetActiveSlot;
pub const Cell = page.Cell;
pub const Coordinate = point.Coordinate;
pub const CSI = Parser.Action.CSI;
pub const DCS = Parser.Action.DCS;
pub const MouseShape = terminal.MouseShape;
pub const Page = page.Page;
pub const PageList = terminal.PageList;
pub const Parser = terminal.Parser;
pub const Pin = PageList.Pin;
pub const Point = point.Point;
pub const RenderState = terminal.RenderState;
pub const Screen = terminal.Screen;
pub const ScreenSet = terminal.ScreenSet;
pub const Selection = terminal.Selection;
pub const SelectionGesture = terminal.SelectionGesture;
pub const size_report = terminal.size_report;
pub const SizeReportStyle = terminal.SizeReportStyle;
pub const StringMap = terminal.StringMap;
pub const Style = terminal.Style;
pub const Terminal = terminal.Terminal;
pub const TerminalStream = terminal.TerminalStream;
pub const Stream = terminal.Stream;
pub const StreamAction = terminal.StreamAction;
pub const UnknownSequence = terminal.UnknownSequence;

pub const Paste = terminal.Paste;
pub const PasteSource = terminal.PasteSource;
pub const PasteError = terminal.PasteError;
pub const Cursor = Screen.Cursor;
pub const CursorStyle = Screen.CursorStyle;
pub const CursorStyleReq = terminal.CursorStyle;
pub const DeviceAttributeReq = terminal.DeviceAttributeReq;
pub const Mode = modes.Mode;
pub const ModePacked = modes.ModePacked;
pub const ModifyKeyFormat = terminal.ModifyKeyFormat;
pub const ProtectedMode = terminal.ProtectedMode;
pub const StatusLineType = terminal.StatusLineType;
pub const StatusDisplay = terminal.StatusDisplay;
pub const EraseDisplay = terminal.EraseDisplay;
pub const EraseLine = terminal.EraseLine;
pub const TabClear = terminal.TabClear;
pub const Attribute = terminal.Attribute;

/// Terminal-specific input encoding is also part of libspectrepro-vt.
pub const input = struct {
    // We have to be careful to only import targeted files within
    // the input package because the full package brings in too many
    // other dependencies.
    const focus = terminal.focus;
    const paste = @import("input/paste.zig");
    const key = @import("input/key.zig");
    const key_encode = @import("input/key_encode.zig");
    const mouse_encode = @import("input/mouse_encode.zig");

    // Focus-related APIs
    pub const max_focus_encode_size = focus.max_encode_size;
    pub const FocusEvent = focus.Event;
    pub const encodeFocus = focus.encode;

    // Paste-related APIs
    pub const PasteError = paste.Error;
    pub const PasteOptions = paste.Options;
    pub const max_paste_frame_size = paste.max_frame_size;
    pub const isSafePaste = paste.isSafe;
    pub const isSafePasteWith = paste.isSafeWith;
    pub const encodePaste = paste.encode;
    pub const encodePasteWriter = paste.encodeWriter;

    // Key encoding
    pub const Key = key.Key;
    pub const KeyAction = key.Action;
    pub const KeyEvent = key.KeyEvent;
    pub const KeyMods = key.Mods;
    pub const KeyEncodeOptions = key_encode.Options;
    pub const encodeKey = key_encode.encode;

    // Mouse encoding
    pub const MouseAction = @import("input/mouse.zig").Action;
    pub const MouseButton = @import("input/mouse.zig").Button;
    pub const MouseEncodeOptions = mouse_encode.Options;
    pub const MouseEncodeEvent = mouse_encode.Event;
    pub const encodeMouse = mouse_encode.encode;
};

/// Unicode utilities that match the terminal's text layout semantics.
pub const unicode = struct {
    const unicode_pkg = @import("unicode/main.zig");

    pub const codepointWidth = unicode_pkg.codepointWidth;
    pub const graphemeWidth = unicode_pkg.graphemeWidth;
};

/// Used for MSVC builds (see below)
var msvc_fltused: c_int = 1;

comptime {
    // If we're building the C library (vs. the Zig module) then
    // we want to reference the C API so that it gets exported.
    if (@import("root") == lib) {
        // MSVC requires this marker whenever floating-point code is present.
        // Zig's compiler_rt only provides it when libc is not linked.
        if (builtin.os.tag == .windows and
            builtin.abi == .msvc and
            builtin.link_mode == .static)
        {
            @export(
                &msvc_fltused,
                .{ .name = "_fltused" },
            );
        }

        // Force-reference our memset override so its export is
        // emitted. This must stay inside the root guard so that
        // downstream Zig module consumers don't get the override
        // injected into their binaries. See quirks_memset.zig.
        _ = @import("quirks_memset.zig");

        const c = terminal.c_api;
        const features = terminal.options;
        if (features.input_encode) {
            @export(&c.key_event_new, .{ .name = "spectrepro_key_event_new" });
            @export(&c.key_event_free, .{ .name = "spectrepro_key_event_free" });
            @export(&c.key_event_set_action, .{ .name = "spectrepro_key_event_set_action" });
            @export(&c.key_event_get_action, .{ .name = "spectrepro_key_event_get_action" });
            @export(&c.key_event_set_key, .{ .name = "spectrepro_key_event_set_key" });
            @export(&c.key_event_get_key, .{ .name = "spectrepro_key_event_get_key" });
            @export(&c.key_event_set_mods, .{ .name = "spectrepro_key_event_set_mods" });
            @export(&c.key_event_get_mods, .{ .name = "spectrepro_key_event_get_mods" });
            @export(&c.key_event_set_consumed_mods, .{ .name = "spectrepro_key_event_set_consumed_mods" });
            @export(&c.key_event_get_consumed_mods, .{ .name = "spectrepro_key_event_get_consumed_mods" });
            @export(&c.key_event_set_composing, .{ .name = "spectrepro_key_event_set_composing" });
            @export(&c.key_event_get_composing, .{ .name = "spectrepro_key_event_get_composing" });
            @export(&c.key_event_set_utf8, .{ .name = "spectrepro_key_event_set_utf8" });
            @export(&c.key_event_get_utf8, .{ .name = "spectrepro_key_event_get_utf8" });
            @export(&c.key_event_set_unshifted_codepoint, .{ .name = "spectrepro_key_event_set_unshifted_codepoint" });
            @export(&c.key_event_get_unshifted_codepoint, .{ .name = "spectrepro_key_event_get_unshifted_codepoint" });
            @export(&c.key_encoder_new, .{ .name = "spectrepro_key_encoder_new" });
            @export(&c.key_encoder_free, .{ .name = "spectrepro_key_encoder_free" });
            @export(&c.key_encoder_setopt, .{ .name = "spectrepro_key_encoder_setopt" });
            @export(&c.key_encoder_setopt_from_terminal, .{ .name = "spectrepro_key_encoder_setopt_from_terminal" });
            @export(&c.key_encoder_encode, .{ .name = "spectrepro_key_encoder_encode" });
            @export(&c.focus_encode, .{ .name = "spectrepro_focus_encode" });
            @export(&c.paste_is_safe, .{ .name = "spectrepro_paste_is_safe" });
            @export(&c.paste_encode, .{ .name = "spectrepro_paste_encode" });
            @export(&c.terminal_paste, .{ .name = "spectrepro_terminal_paste" });
            @export(&c.mouse_event_new, .{ .name = "spectrepro_mouse_event_new" });
            @export(&c.mouse_event_free, .{ .name = "spectrepro_mouse_event_free" });
            @export(&c.mouse_event_set_action, .{ .name = "spectrepro_mouse_event_set_action" });
            @export(&c.mouse_event_get_action, .{ .name = "spectrepro_mouse_event_get_action" });
            @export(&c.mouse_event_set_button, .{ .name = "spectrepro_mouse_event_set_button" });
            @export(&c.mouse_event_clear_button, .{ .name = "spectrepro_mouse_event_clear_button" });
            @export(&c.mouse_event_get_button, .{ .name = "spectrepro_mouse_event_get_button" });
            @export(&c.mouse_event_set_mods, .{ .name = "spectrepro_mouse_event_set_mods" });
            @export(&c.mouse_event_get_mods, .{ .name = "spectrepro_mouse_event_get_mods" });
            @export(&c.mouse_event_set_position, .{ .name = "spectrepro_mouse_event_set_position" });
            @export(&c.mouse_event_get_position, .{ .name = "spectrepro_mouse_event_get_position" });
            @export(&c.mouse_encoder_new, .{ .name = "spectrepro_mouse_encoder_new" });
            @export(&c.mouse_encoder_free, .{ .name = "spectrepro_mouse_encoder_free" });
            @export(&c.mouse_encoder_setopt, .{ .name = "spectrepro_mouse_encoder_setopt" });
            @export(&c.mouse_encoder_setopt_from_terminal, .{ .name = "spectrepro_mouse_encoder_setopt_from_terminal" });
            @export(&c.mouse_encoder_reset, .{ .name = "spectrepro_mouse_encoder_reset" });
            @export(&c.mouse_encoder_encode, .{ .name = "spectrepro_mouse_encoder_encode" });
        }
        @export(&c.osc_new, .{ .name = "spectrepro_osc_new" });
        @export(&c.osc_free, .{ .name = "spectrepro_osc_free" });
        @export(&c.osc_next, .{ .name = "spectrepro_osc_next" });
        @export(&c.osc_reset, .{ .name = "spectrepro_osc_reset" });
        @export(&c.osc_end, .{ .name = "spectrepro_osc_end" });
        @export(&c.osc_command_type, .{ .name = "spectrepro_osc_command_type" });
        @export(&c.osc_command_data, .{ .name = "spectrepro_osc_command_data" });
        @export(&c.color_scheme_report_encode, .{ .name = "spectrepro_color_scheme_report_encode" });
        @export(&c.mode_report_encode, .{ .name = "spectrepro_mode_report_encode" });
        @export(&c.unicode_codepoint_width, .{ .name = "spectrepro_unicode_codepoint_width" });
        @export(&c.unicode_grapheme_width, .{ .name = "spectrepro_unicode_grapheme_width" });
        @export(&c.size_report_encode, .{ .name = "spectrepro_size_report_encode" });
        @export(&c.style_default, .{ .name = "spectrepro_style_default" });
        @export(&c.style_is_default, .{ .name = "spectrepro_style_is_default" });
        @export(&c.sys_log_stderr, .{ .name = "spectrepro_sys_log_stderr" });
        @export(&c.sys_set, .{ .name = "spectrepro_sys_set" });
        if (features.grid_introspection) {
            @export(&c.cell_get, .{ .name = "spectrepro_cell_get" });
            @export(&c.cell_get_multi, .{ .name = "spectrepro_cell_get_multi" });
            @export(&c.row_get, .{ .name = "spectrepro_row_get" });
            @export(&c.row_get_multi, .{ .name = "spectrepro_row_get_multi" });
        }
        if (features.color) {
            @export(&c.color_rgb_get, .{ .name = "spectrepro_color_rgb_get" });
            @export(&c.color_contrast, .{ .name = "spectrepro_color_contrast" });
            @export(&c.color_luminance, .{ .name = "spectrepro_color_luminance" });
            @export(&c.color_parse, .{ .name = "spectrepro_color_parse" });
            @export(&c.color_parse_palette_entry, .{ .name = "spectrepro_color_parse_palette_entry" });
            @export(&c.color_parse_x11, .{ .name = "spectrepro_color_parse_x11" });
            @export(&c.color_palette_default, .{ .name = "spectrepro_color_palette_default" });
            @export(&c.color_palette_generate, .{ .name = "spectrepro_color_palette_generate" });
            @export(&c.color_perceived_luminance, .{ .name = "spectrepro_color_perceived_luminance" });
            @export(&c.color_x11_name_count, .{ .name = "spectrepro_color_x11_name_count" });
            @export(&c.color_x11_names, .{ .name = "spectrepro_color_x11_names" });
        }
        @export(&c.sgr_new, .{ .name = "spectrepro_sgr_new" });
        @export(&c.sgr_free, .{ .name = "spectrepro_sgr_free" });
        @export(&c.sgr_reset, .{ .name = "spectrepro_sgr_reset" });
        @export(&c.sgr_set_params, .{ .name = "spectrepro_sgr_set_params" });
        @export(&c.sgr_next, .{ .name = "spectrepro_sgr_next" });
        @export(&c.sgr_unknown_full, .{ .name = "spectrepro_sgr_unknown_full" });
        @export(&c.sgr_unknown_partial, .{ .name = "spectrepro_sgr_unknown_partial" });
        @export(&c.sgr_attribute_tag, .{ .name = "spectrepro_sgr_attribute_tag" });
        @export(&c.sgr_attribute_value, .{ .name = "spectrepro_sgr_attribute_value" });
        if (features.formatter) {
            @export(&c.formatter_terminal_new, .{ .name = "spectrepro_formatter_terminal_new" });
            @export(&c.formatter_format, .{ .name = "spectrepro_formatter_format" });
            @export(&c.formatter_format_buf, .{ .name = "spectrepro_formatter_format_buf" });
            @export(&c.formatter_format_alloc, .{ .name = "spectrepro_formatter_format_alloc" });
            @export(&c.formatter_free, .{ .name = "spectrepro_formatter_free" });
        }
        if (features.formatter and features.selection) {
            @export(&c.terminal_selection_format_buf, .{ .name = "spectrepro_terminal_selection_format_buf" });
            @export(&c.terminal_selection_format_alloc, .{ .name = "spectrepro_terminal_selection_format_alloc" });
        }
        if (features.render_state) {
            @export(&c.render_state_new, .{ .name = "spectrepro_render_state_new" });
            @export(&c.render_state_update, .{ .name = "spectrepro_render_state_update" });
            @export(&c.render_state_begin_update, .{ .name = "spectrepro_render_state_begin_update" });
            @export(&c.render_state_end_update, .{ .name = "spectrepro_render_state_end_update" });
            @export(&c.render_state_clean, .{ .name = "spectrepro_render_state_clean" });
            @export(&c.render_state_get, .{ .name = "spectrepro_render_state_get" });
            @export(&c.render_state_get_multi, .{ .name = "spectrepro_render_state_get_multi" });
            @export(&c.render_state_set, .{ .name = "spectrepro_render_state_set" });
            @export(&c.render_state_row_iterator_new, .{ .name = "spectrepro_render_state_row_iterator_new" });
            @export(&c.render_state_row_iterator_next, .{ .name = "spectrepro_render_state_row_iterator_next" });
            @export(&c.render_state_row_iterator_next_dirty, .{ .name = "spectrepro_render_state_row_iterator_next_dirty" });
            @export(&c.render_state_row_get, .{ .name = "spectrepro_render_state_row_get" });
            @export(&c.render_state_row_get_multi, .{ .name = "spectrepro_render_state_row_get_multi" });
            @export(&c.render_state_row_set, .{ .name = "spectrepro_render_state_row_set" });
            @export(&c.render_state_row_iterator_free, .{ .name = "spectrepro_render_state_row_iterator_free" });
            @export(&c.render_state_row_cells_new, .{ .name = "spectrepro_render_state_row_cells_new" });
            @export(&c.render_state_row_cells_next, .{ .name = "spectrepro_render_state_row_cells_next" });
            @export(&c.render_state_row_cells_select, .{ .name = "spectrepro_render_state_row_cells_select" });
            @export(&c.render_state_row_cells_get, .{ .name = "spectrepro_render_state_row_cells_get" });
            @export(&c.render_state_row_cells_get_multi, .{ .name = "spectrepro_render_state_row_cells_get_multi" });
            @export(&c.render_state_row_cells_free, .{ .name = "spectrepro_render_state_row_cells_free" });
            @export(&c.render_state_free, .{ .name = "spectrepro_render_state_free" });
        }
        @export(&c.terminal_new, .{ .name = "spectrepro_terminal_new" });
        @export(&c.terminal_free, .{ .name = "spectrepro_terminal_free" });
        @export(&c.terminal_reset, .{ .name = "spectrepro_terminal_reset" });
        @export(&c.terminal_resize, .{ .name = "spectrepro_terminal_resize" });
        @export(&c.terminal_set, .{ .name = "spectrepro_terminal_set" });
        @export(&c.terminal_vt_write, .{ .name = "spectrepro_terminal_vt_write" });
        @export(&c.terminal_vt_write_until_ground, .{ .name = "spectrepro_terminal_vt_write_until_ground" });
        @export(&c.terminal_scroll_viewport, .{ .name = "spectrepro_terminal_scroll_viewport" });
        @export(&c.terminal_compression_activity, .{ .name = "spectrepro_terminal_compression_activity" });
        @export(&c.terminal_compress, .{ .name = "spectrepro_terminal_compress" });
        @export(&c.terminal_get, .{ .name = "spectrepro_terminal_get" });
        @export(&c.terminal_get_multi, .{ .name = "spectrepro_terminal_get_multi" });
        @export(&c.terminal_continuation_write, .{ .name = "spectrepro_terminal_continuation_write" });
        @export(&c.terminal_continuation_buf, .{ .name = "spectrepro_terminal_continuation_buf" });
        @export(&c.terminal_continuation_alloc, .{ .name = "spectrepro_terminal_continuation_alloc" });
        if (features.selection) {
            @export(&c.terminal_select_word, .{ .name = "spectrepro_terminal_select_word" });
            @export(&c.terminal_select_word_between, .{ .name = "spectrepro_terminal_select_word_between" });
            @export(&c.terminal_select_line, .{ .name = "spectrepro_terminal_select_line" });
            @export(&c.terminal_select_all, .{ .name = "spectrepro_terminal_select_all" });
            @export(&c.terminal_select_output, .{ .name = "spectrepro_terminal_select_output" });
            @export(&c.terminal_selection_adjust, .{ .name = "spectrepro_terminal_selection_adjust" });
            @export(&c.terminal_selection_order, .{ .name = "spectrepro_terminal_selection_order" });
            @export(&c.terminal_selection_ordered, .{ .name = "spectrepro_terminal_selection_ordered" });
            @export(&c.terminal_selection_contains, .{ .name = "spectrepro_terminal_selection_contains" });
            @export(&c.terminal_selection_equal, .{ .name = "spectrepro_terminal_selection_equal" });
            @export(&c.selection_gesture_new, .{ .name = "spectrepro_selection_gesture_new" });
            @export(&c.selection_gesture_free, .{ .name = "spectrepro_selection_gesture_free" });
            @export(&c.selection_gesture_reset, .{ .name = "spectrepro_selection_gesture_reset" });
            @export(&c.selection_gesture_event, .{ .name = "spectrepro_selection_gesture_event" });
            @export(&c.selection_gesture_get, .{ .name = "spectrepro_selection_gesture_get" });
            @export(&c.selection_gesture_get_multi, .{ .name = "spectrepro_selection_gesture_get_multi" });
            @export(&c.selection_gesture_event_new, .{ .name = "spectrepro_selection_gesture_event_new" });
            @export(&c.selection_gesture_event_free, .{ .name = "spectrepro_selection_gesture_event_free" });
            @export(&c.selection_gesture_event_set, .{ .name = "spectrepro_selection_gesture_event_set" });
        }
        if (features.search) {
            @export(&c.search_new, .{ .name = "spectrepro_search_new" });
            @export(&c.search_free, .{ .name = "spectrepro_search_free" });
            @export(&c.search_tick, .{ .name = "spectrepro_search_tick" });
            @export(&c.search_feed, .{ .name = "spectrepro_search_feed" });
            @export(&c.search_run, .{ .name = "spectrepro_search_run" });
            @export(&c.search_set, .{ .name = "spectrepro_search_set" });
            @export(&c.search_get, .{ .name = "spectrepro_search_get" });
            @export(&c.search_get_multi, .{ .name = "spectrepro_search_get_multi" });
        }
        // Selections are expressed in grid references, so the untracked
        // reference constructors are required by both features.
        if (features.grid_introspection or features.selection) {
            @export(&c.terminal_grid_ref, .{ .name = "spectrepro_terminal_grid_ref" });
            @export(&c.terminal_point_from_grid_ref, .{ .name = "spectrepro_terminal_point_from_grid_ref" });
        }
        if (features.grid_introspection) {
            @export(&c.terminal_grid_ref_track, .{ .name = "spectrepro_terminal_grid_ref_track" });
        }
        if (features.snapshot) {
            @export(&c.snapshot_encode, .{ .name = "spectrepro_snapshot_encode" });
            @export(&c.snapshot_encode_buf, .{ .name = "spectrepro_snapshot_encode_buf" });
            @export(&c.snapshot_encode_alloc, .{ .name = "spectrepro_snapshot_encode_alloc" });
            @export(&c.snapshot_decoder_new, .{ .name = "spectrepro_snapshot_decoder_new" });
            @export(&c.snapshot_decoder_new_buf, .{ .name = "spectrepro_snapshot_decoder_new_buf" });
            @export(&c.snapshot_decoder_free, .{ .name = "spectrepro_snapshot_decoder_free" });
            @export(&c.snapshot_decoder_set, .{ .name = "spectrepro_snapshot_decoder_set" });
            @export(&c.snapshot_decoder_get, .{ .name = "spectrepro_snapshot_decoder_get" });
            @export(&c.snapshot_decoder_get_multi, .{ .name = "spectrepro_snapshot_decoder_get_multi" });
            @export(&c.snapshot_decoder_ready, .{ .name = "spectrepro_snapshot_decoder_ready" });
            @export(&c.snapshot_decoder_next, .{ .name = "spectrepro_snapshot_decoder_next" });
            @export(&c.snapshot_decoder_decode, .{ .name = "spectrepro_snapshot_decoder_decode" });
        }
        if (features.kitty_graphics) {
            @export(&c.kitty_graphics_get, .{ .name = "spectrepro_kitty_graphics_get" });
            @export(&c.kitty_graphics_image, .{ .name = "spectrepro_kitty_graphics_image" });
            @export(&c.kitty_graphics_image_get, .{ .name = "spectrepro_kitty_graphics_image_get" });
            @export(&c.kitty_graphics_image_get_multi, .{ .name = "spectrepro_kitty_graphics_image_get_multi" });
            @export(&c.kitty_graphics_placement_iterator_new, .{ .name = "spectrepro_kitty_graphics_placement_iterator_new" });
            @export(&c.kitty_graphics_placement_iterator_free, .{ .name = "spectrepro_kitty_graphics_placement_iterator_free" });
            @export(&c.kitty_graphics_placement_iterator_set, .{ .name = "spectrepro_kitty_graphics_placement_iterator_set" });
            @export(&c.kitty_graphics_placement_next, .{ .name = "spectrepro_kitty_graphics_placement_next" });
            @export(&c.kitty_graphics_placement_get, .{ .name = "spectrepro_kitty_graphics_placement_get" });
            @export(&c.kitty_graphics_placement_get_multi, .{ .name = "spectrepro_kitty_graphics_placement_get_multi" });
            @export(&c.kitty_graphics_placement_rect, .{ .name = "spectrepro_kitty_graphics_placement_rect" });
            @export(&c.kitty_graphics_placement_pixel_size, .{ .name = "spectrepro_kitty_graphics_placement_pixel_size" });
            @export(&c.kitty_graphics_placement_grid_size, .{ .name = "spectrepro_kitty_graphics_placement_grid_size" });
            @export(&c.kitty_graphics_placement_viewport_pos, .{ .name = "spectrepro_kitty_graphics_placement_viewport_pos" });
            @export(&c.kitty_graphics_placement_source_rect, .{ .name = "spectrepro_kitty_graphics_placement_source_rect" });
            @export(&c.kitty_graphics_placement_render_info, .{ .name = "spectrepro_kitty_graphics_placement_render_info" });
        }
        if (features.grid_introspection) {
            @export(&c.grid_ref_cell, .{ .name = "spectrepro_grid_ref_cell" });
            @export(&c.grid_ref_row, .{ .name = "spectrepro_grid_ref_row" });
            @export(&c.grid_ref_graphemes, .{ .name = "spectrepro_grid_ref_graphemes" });
            @export(&c.grid_ref_hyperlink_uri, .{ .name = "spectrepro_grid_ref_hyperlink_uri" });
            @export(&c.grid_ref_style, .{ .name = "spectrepro_grid_ref_style" });
            @export(&c.tracked_grid_ref_free, .{ .name = "spectrepro_tracked_grid_ref_free" });
            @export(&c.tracked_grid_ref_has_value, .{ .name = "spectrepro_tracked_grid_ref_has_value" });
            @export(&c.tracked_grid_ref_point, .{ .name = "spectrepro_tracked_grid_ref_point" });
            @export(&c.tracked_grid_ref_set, .{ .name = "spectrepro_tracked_grid_ref_set" });
        }
        if (features.grid_introspection and features.snapshot) {
            @export(&c.tracked_grid_ref_snapshot, .{ .name = "spectrepro_tracked_grid_ref_snapshot" });
        }
        @export(&c.build_info, .{ .name = "spectrepro_build_info" });
        @export(&c.type_json, .{ .name = "spectrepro_type_json" });
        @export(&c.alloc_alloc, .{ .name = "spectrepro_alloc" });
        @export(&c.alloc_free, .{ .name = "spectrepro_free" });

        // On Wasm we need to export our allocator convenience functions.
        if (builtin.target.cpu.arch.isWasm()) {
            const alloc = @import("lib/allocator/wasm.zig");
            @export(&alloc.allocBytes, .{ .name = "spectrepro_wasm_alloc" });
            @export(&alloc.freeBytes, .{ .name = "spectrepro_wasm_free" });
            @export(&alloc.allocOpaque, .{ .name = "spectrepro_wasm_alloc_opaque" });
            @export(&alloc.freeOpaque, .{ .name = "spectrepro_wasm_free_opaque" });
            @export(&alloc.takeOpaque, .{ .name = "spectrepro_wasm_take_opaque" });
        }
    }
}

pub const std_options: std.Options = opts: {
    var options: std.Options = .{};

    if (native_freestanding) {
        // Freestanding targets don't have an OS page size. We still need an
        // alignment for terminal page allocations, and 16 covers everything
        // stored in a page without requiring 4 KiB-aligned embedded heaps.
        options.page_size_min = 16;
        options.page_size_max = 16;
        options.allow_stack_tracing = false;
    }

    if (builtin.target.cpu.arch.isWasm()) {
        // In non-debug modes, we want to ship effectively no logging
        // warn and lower add ~200KB at the time of this comment.
        if (builtin.mode == .Debug) {
            options.log_level = .debug;
            options.logFn = @import("os/wasm/log.zig").log;
        } else {
            options.log_level = .err;
            options.logFn = @import("os/wasm/log.zig").noop;
        }
    } else if (terminal.options.c_abi) {
        // For C ABI builds, use a custom log function that dispatches to an
        // embedder-provided callback (or silently discards when none is set).
        options.logFn = @import("terminal/c/sys.zig").logFn;
    }

    if (builtin.target.os.tag.isDarwin() and builtin.target.os.tag != .macos) {
        // If are building for a non-MacOS Darwin target (e.g., iOS), we need to
        // disable stack tracing for the time being. This is due to the fact that
        // Zig switched to using _dyld_get_image_header_containing_address and some
        // other (deprecated) calls to speed up stack unwinding; these calls are
        // available on MacOS, but not on other platforms.
        //
        // A fix has already been submitted to exempt non-MacOS (but still Darwin)
        // targets, so this can likely be removed in Zig 0.17.0, or a 0.16.x patch
        // version if it releases beforehand.
        //
        // More details:
        //   https://codeberg.org/ziglang/zig/commit/89f86e46d278a35a613bbc662cdd3f65ffc76ed7
        //
        options.allow_stack_tracing = false;
    }

    break :opts options;
};

/// True for builds where we keep the full std debug machinery (stack
/// traces on panic, std.debug.print, etc.). These builds are for
/// development, where the roughly 160KB of binary size it costs is
/// worth it.
const native_freestanding = builtin.target.os.tag == .freestanding and
    !builtin.target.cpu.arch.isWasm();

const debug_machinery: bool = !native_freestanding and
    (builtin.is_test or switch (builtin.mode) {
        .Debug, .ReleaseSafe => true,
        .ReleaseFast, .ReleaseSmall => false,
    });

/// The panic handler for when this file is the root module.
///
/// In ReleaseFast and ReleaseSmall builds we print the panic message to
/// stderr and trap, but do not attempt to unwind the stack to print a
/// stack trace.
pub const panic: type = if (debug_machinery)
    std.debug.FullPanic(std.debug.defaultPanic)
else
    std.debug.FullPanic(tinyPanicImpl);

/// Guards release builds against accidentally reintroducing the std
/// debug Io machinery.
///
/// `std.Options.debug_io` defaults to `std.Io.Threaded`, and anything
/// that reaches it (std.debug.print, std.debug.lockStderr, the default
/// std.log handler, etc.) pins Threaded's entire vtable into the binary:
/// roughly 110KB of unreachable code.
///
/// This verifies nothing ever touches it.
pub const std_options_debug_io: std.Io = if (debug_machinery)
    std.Io.Threaded.global_single_threaded.io()
else
    @compileError(
        \\The std debug Io machinery (std.debug.print, std.debug.lockStderr,
        \\std.log's default handler, ...) is disabled in libspectrepro-vt release
        \\builds because it costs ~110KB of binary size. Use std.log (routed
        \\through our logFn), os/stderr.zig for raw diagnostic writes, or
        \\gate the code on debug builds.
    );

/// Prints the panic message to stderr (best-effort) and traps.
///
/// This intentionally avoids `std.debug.lockStderr`, which routes through
/// `std.Options.debug_io` and would keep the entire `std.Io.Threaded`
/// vtable alive in the binary which takes up hundreds of KB.
///
/// This is safe to call from any thread (and even from signal handlers):
/// it takes no locks, performs no allocation, and touches no shared
/// mutable state. The message is emitted with a single raw write so that
/// concurrent stderr output doesn't interleave with it.
fn tinyPanicImpl(msg: []const u8, ra: ?usize) noreturn {
    @branchHint(.cold);
    _ = ra;

    // 256 bytes is enough for most messages, so try that first
    // so that we can try to write in a single syscall.
    var buf: [256]u8 = undefined;
    if (std.fmt.bufPrint(
        &buf,
        "panic: {s}\n",
        .{msg},
    )) |line| {
        stderr.write(line);
    } else |_| {
        stderr.write("panic: ");
        stderr.write(msg);
        stderr.write("\n");
    }

    // Trap forces a standard crash that embedder-provided debuggers
    // or environments can catch.
    @trap();
}

test {
    // Zig 0.16.0 has made test logging more strict. Now, *anything* that gets
    // printed to stderr results in a "failed command" message, even if the
    // tests ultimately passed. To reduce confusion here (and honestly, test
    // log spam in general), we bump the default testing log level to error.
    @import("std").testing.log_level = std.log.Level.err;

    _ = terminal;
    _ = @import("lib/main.zig");
    @import("std").testing.refAllDecls(input);
    @import("std").testing.refAllDecls(unicode);
    if (comptime terminal.options.c_abi) {
        _ = terminal.c_api;
    }
}
