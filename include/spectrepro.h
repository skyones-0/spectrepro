// SpectrePro's internal embedder API, a.k.a. "libspectrepro-internal".
//
// The only consumer of this API is the macOS app, and while it is fairly
// comprehensive, it is tailored to the needs of the macOS app and not designed
// for external use, hence why most functions are undocumented and some are
// macOS-specific (e.g. ones dealing with the Metal graphics API).
// 
// External embedders should instead use `libspectrepro-vt` or other related
// packages, which are extensively documented and designed from the ground up
// to be used in other software. Header files for which can be found in
// `include/spectrepro/`.
#ifndef SPECTREPRO_H
#define SPECTREPRO_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef _MSC_VER
#include <BaseTsd.h>
typedef SSIZE_T ssize_t;
#else
#include <sys/types.h>
#endif

//-------------------------------------------------------------------
// Macros

#define SPECTREPRO_SUCCESS 0

// Symbol visibility for shared library builds. On Windows, functions
// are exported from the DLL when building and imported when consuming.
// On other platforms with GCC/Clang, functions are marked with default
// visibility so they remain accessible when the library is built with
// -fvisibility=hidden. For static library builds, define SPECTREPRO_STATIC
// before including this header to make this a no-op.
#ifndef SPECTREPRO_API
#if defined(SPECTREPRO_STATIC)
  #define SPECTREPRO_API
#elif defined(_WIN32) || defined(_WIN64)
  #ifdef SPECTREPRO_BUILD_SHARED
    #define SPECTREPRO_API __declspec(dllexport)
  #else
    #define SPECTREPRO_API __declspec(dllimport)
  #endif
#elif defined(__GNUC__) && __GNUC__ >= 4
  #define SPECTREPRO_API __attribute__((visibility("default")))
#else
  #define SPECTREPRO_API
#endif
#endif

//-------------------------------------------------------------------
// Types

// Opaque types
typedef void* spectrepro_app_t;
typedef void* spectrepro_config_t;
typedef void* spectrepro_surface_t;
typedef void* spectrepro_inspector_t;

// All the types below are fully defined and must be kept in sync with
// their Zig counterparts. Any changes to these types MUST have an associated
// Zig change.
typedef enum {
  SPECTREPRO_PLATFORM_INVALID,
  SPECTREPRO_PLATFORM_MACOS,
  SPECTREPRO_PLATFORM_IOS,
} spectrepro_platform_e;

typedef enum {
  SPECTREPRO_CLIPBOARD_STANDARD,
  SPECTREPRO_CLIPBOARD_SELECTION,
  SPECTREPRO_CLIPBOARD_PRIMARY,
} spectrepro_clipboard_e;

// One representation of clipboard contents. The data is binary-safe with
// an explicit length; it is not necessarily null-terminated.
typedef struct {
  const char *mime;
  const char *data;
  size_t len;
} spectrepro_clipboard_content_s;

// The payload for completing a clipboard read request. See
// spectrepro_surface_complete_clipboard_request.
typedef struct {
  const spectrepro_clipboard_content_s *contents;
  size_t contents_len;
  const char *const *available;
  size_t available_len;
  bool confirmed;
  bool remember;
} spectrepro_clipboard_complete_s;

// The payload of a clipboard read confirmation request: the would-be
// completion contents plus the information shown in the permission
// prompt. See spectrepro_runtime_confirm_read_clipboard_cb.
typedef struct {
  const spectrepro_clipboard_content_s *contents;
  size_t contents_len;
  const char *const *available;
  size_t available_len;
  const char *name;
  bool can_remember;
} spectrepro_clipboard_confirm_s;

typedef enum {
  SPECTREPRO_CLIPBOARD_REQUEST_PASTE,
  SPECTREPRO_CLIPBOARD_REQUEST_OSC_52_READ,
  SPECTREPRO_CLIPBOARD_REQUEST_OSC_52_WRITE,
  SPECTREPRO_CLIPBOARD_REQUEST_KITTY_READ,
  SPECTREPRO_CLIPBOARD_REQUEST_KITTY_WRITE,
  SPECTREPRO_CLIPBOARD_REQUEST_LIST,
} spectrepro_clipboard_request_e;

// apprt.ClipboardReadResult
typedef enum {
  SPECTREPRO_CLIPBOARD_READ_STARTED,
  SPECTREPRO_CLIPBOARD_READ_UNAVAILABLE,
  SPECTREPRO_CLIPBOARD_READ_UNSUPPORTED,
} spectrepro_clipboard_read_result_e;

typedef enum {
  SPECTREPRO_MOUSE_RELEASE,
  SPECTREPRO_MOUSE_PRESS,
} spectrepro_input_mouse_state_e;

typedef enum {
  SPECTREPRO_MOUSE_UNKNOWN,
  SPECTREPRO_MOUSE_LEFT,
  SPECTREPRO_MOUSE_RIGHT,
  SPECTREPRO_MOUSE_MIDDLE,
  SPECTREPRO_MOUSE_FOUR,
  SPECTREPRO_MOUSE_FIVE,
  SPECTREPRO_MOUSE_SIX,
  SPECTREPRO_MOUSE_SEVEN,
  SPECTREPRO_MOUSE_EIGHT,
  SPECTREPRO_MOUSE_NINE,
  SPECTREPRO_MOUSE_TEN,
  SPECTREPRO_MOUSE_ELEVEN,
} spectrepro_input_mouse_button_e;

typedef enum {
  SPECTREPRO_MOUSE_MOMENTUM_NONE,
  SPECTREPRO_MOUSE_MOMENTUM_BEGAN,
  SPECTREPRO_MOUSE_MOMENTUM_STATIONARY,
  SPECTREPRO_MOUSE_MOMENTUM_CHANGED,
  SPECTREPRO_MOUSE_MOMENTUM_ENDED,
  SPECTREPRO_MOUSE_MOMENTUM_CANCELLED,
  SPECTREPRO_MOUSE_MOMENTUM_MAY_BEGIN,
} spectrepro_input_mouse_momentum_e;

typedef enum {
  SPECTREPRO_COLOR_SCHEME_LIGHT = 0,
  SPECTREPRO_COLOR_SCHEME_DARK = 1,
} spectrepro_color_scheme_e;

// This is a packed struct (see src/input/mouse.zig) but the C standard
// afaik doesn't let us reliably define packed structs so we build it up
// from scratch.
typedef int spectrepro_input_scroll_mods_t;

typedef enum {
  SPECTREPRO_MODS_NONE = 0,
  SPECTREPRO_MODS_SHIFT = 1 << 0,
  SPECTREPRO_MODS_CTRL = 1 << 1,
  SPECTREPRO_MODS_ALT = 1 << 2,
  SPECTREPRO_MODS_SUPER = 1 << 3,
  SPECTREPRO_MODS_CAPS = 1 << 4,
  SPECTREPRO_MODS_NUM = 1 << 5,
  SPECTREPRO_MODS_SHIFT_RIGHT = 1 << 6,
  SPECTREPRO_MODS_CTRL_RIGHT = 1 << 7,
  SPECTREPRO_MODS_ALT_RIGHT = 1 << 8,
  SPECTREPRO_MODS_SUPER_RIGHT = 1 << 9,
} spectrepro_input_mods_e;

typedef enum {
  SPECTREPRO_BINDING_FLAGS_CONSUMED = 1 << 0,
  SPECTREPRO_BINDING_FLAGS_ALL = 1 << 1,
  SPECTREPRO_BINDING_FLAGS_GLOBAL = 1 << 2,
  SPECTREPRO_BINDING_FLAGS_PERFORMABLE = 1 << 3,
} spectrepro_binding_flags_e;

typedef enum {
  SPECTREPRO_ACTION_RELEASE,
  SPECTREPRO_ACTION_PRESS,
  SPECTREPRO_ACTION_REPEAT,
} spectrepro_input_action_e;

// Based on: https://www.w3.org/TR/uievents-code/
typedef enum {
  SPECTREPRO_KEY_UNIDENTIFIED,

  // "Writing System Keys" § 3.1.1
  SPECTREPRO_KEY_BACKQUOTE,
  SPECTREPRO_KEY_BACKSLASH,
  SPECTREPRO_KEY_BRACKET_LEFT,
  SPECTREPRO_KEY_BRACKET_RIGHT,
  SPECTREPRO_KEY_COMMA,
  SPECTREPRO_KEY_DIGIT_0,
  SPECTREPRO_KEY_DIGIT_1,
  SPECTREPRO_KEY_DIGIT_2,
  SPECTREPRO_KEY_DIGIT_3,
  SPECTREPRO_KEY_DIGIT_4,
  SPECTREPRO_KEY_DIGIT_5,
  SPECTREPRO_KEY_DIGIT_6,
  SPECTREPRO_KEY_DIGIT_7,
  SPECTREPRO_KEY_DIGIT_8,
  SPECTREPRO_KEY_DIGIT_9,
  SPECTREPRO_KEY_EQUAL,
  SPECTREPRO_KEY_INTL_BACKSLASH,
  SPECTREPRO_KEY_INTL_RO,
  SPECTREPRO_KEY_INTL_YEN,
  SPECTREPRO_KEY_A,
  SPECTREPRO_KEY_B,
  SPECTREPRO_KEY_C,
  SPECTREPRO_KEY_D,
  SPECTREPRO_KEY_E,
  SPECTREPRO_KEY_F,
  SPECTREPRO_KEY_G,
  SPECTREPRO_KEY_H,
  SPECTREPRO_KEY_I,
  SPECTREPRO_KEY_J,
  SPECTREPRO_KEY_K,
  SPECTREPRO_KEY_L,
  SPECTREPRO_KEY_M,
  SPECTREPRO_KEY_N,
  SPECTREPRO_KEY_O,
  SPECTREPRO_KEY_P,
  SPECTREPRO_KEY_Q,
  SPECTREPRO_KEY_R,
  SPECTREPRO_KEY_S,
  SPECTREPRO_KEY_T,
  SPECTREPRO_KEY_U,
  SPECTREPRO_KEY_V,
  SPECTREPRO_KEY_W,
  SPECTREPRO_KEY_X,
  SPECTREPRO_KEY_Y,
  SPECTREPRO_KEY_Z,
  SPECTREPRO_KEY_MINUS,
  SPECTREPRO_KEY_PERIOD,
  SPECTREPRO_KEY_QUOTE,
  SPECTREPRO_KEY_SEMICOLON,
  SPECTREPRO_KEY_SLASH,

  // "Functional Keys" § 3.1.2
  SPECTREPRO_KEY_ALT_LEFT,
  SPECTREPRO_KEY_ALT_RIGHT,
  SPECTREPRO_KEY_BACKSPACE,
  SPECTREPRO_KEY_CAPS_LOCK,
  SPECTREPRO_KEY_CONTEXT_MENU,
  SPECTREPRO_KEY_CONTROL_LEFT,
  SPECTREPRO_KEY_CONTROL_RIGHT,
  SPECTREPRO_KEY_ENTER,
  SPECTREPRO_KEY_META_LEFT,
  SPECTREPRO_KEY_META_RIGHT,
  SPECTREPRO_KEY_SHIFT_LEFT,
  SPECTREPRO_KEY_SHIFT_RIGHT,
  SPECTREPRO_KEY_SPACE,
  SPECTREPRO_KEY_TAB,
  SPECTREPRO_KEY_CONVERT,
  SPECTREPRO_KEY_KANA_MODE,
  SPECTREPRO_KEY_NON_CONVERT,

  // "Control Pad Section" § 3.2
  SPECTREPRO_KEY_DELETE,
  SPECTREPRO_KEY_END,
  SPECTREPRO_KEY_HELP,
  SPECTREPRO_KEY_HOME,
  SPECTREPRO_KEY_INSERT,
  SPECTREPRO_KEY_PAGE_DOWN,
  SPECTREPRO_KEY_PAGE_UP,

  // "Arrow Pad Section" § 3.3
  SPECTREPRO_KEY_ARROW_DOWN,
  SPECTREPRO_KEY_ARROW_LEFT,
  SPECTREPRO_KEY_ARROW_RIGHT,
  SPECTREPRO_KEY_ARROW_UP,

  // "Numpad Section" § 3.4
  SPECTREPRO_KEY_NUM_LOCK,
  SPECTREPRO_KEY_NUMPAD_0,
  SPECTREPRO_KEY_NUMPAD_1,
  SPECTREPRO_KEY_NUMPAD_2,
  SPECTREPRO_KEY_NUMPAD_3,
  SPECTREPRO_KEY_NUMPAD_4,
  SPECTREPRO_KEY_NUMPAD_5,
  SPECTREPRO_KEY_NUMPAD_6,
  SPECTREPRO_KEY_NUMPAD_7,
  SPECTREPRO_KEY_NUMPAD_8,
  SPECTREPRO_KEY_NUMPAD_9,
  SPECTREPRO_KEY_NUMPAD_ADD,
  SPECTREPRO_KEY_NUMPAD_BACKSPACE,
  SPECTREPRO_KEY_NUMPAD_CLEAR,
  SPECTREPRO_KEY_NUMPAD_CLEAR_ENTRY,
  SPECTREPRO_KEY_NUMPAD_COMMA,
  SPECTREPRO_KEY_NUMPAD_DECIMAL,
  SPECTREPRO_KEY_NUMPAD_DIVIDE,
  SPECTREPRO_KEY_NUMPAD_ENTER,
  SPECTREPRO_KEY_NUMPAD_EQUAL,
  SPECTREPRO_KEY_NUMPAD_MEMORY_ADD,
  SPECTREPRO_KEY_NUMPAD_MEMORY_CLEAR,
  SPECTREPRO_KEY_NUMPAD_MEMORY_RECALL,
  SPECTREPRO_KEY_NUMPAD_MEMORY_STORE,
  SPECTREPRO_KEY_NUMPAD_MEMORY_SUBTRACT,
  SPECTREPRO_KEY_NUMPAD_MULTIPLY,
  SPECTREPRO_KEY_NUMPAD_PAREN_LEFT,
  SPECTREPRO_KEY_NUMPAD_PAREN_RIGHT,
  SPECTREPRO_KEY_NUMPAD_SUBTRACT,
  SPECTREPRO_KEY_NUMPAD_SEPARATOR,
  SPECTREPRO_KEY_NUMPAD_UP,
  SPECTREPRO_KEY_NUMPAD_DOWN,
  SPECTREPRO_KEY_NUMPAD_RIGHT,
  SPECTREPRO_KEY_NUMPAD_LEFT,
  SPECTREPRO_KEY_NUMPAD_BEGIN,
  SPECTREPRO_KEY_NUMPAD_HOME,
  SPECTREPRO_KEY_NUMPAD_END,
  SPECTREPRO_KEY_NUMPAD_INSERT,
  SPECTREPRO_KEY_NUMPAD_DELETE,
  SPECTREPRO_KEY_NUMPAD_PAGE_UP,
  SPECTREPRO_KEY_NUMPAD_PAGE_DOWN,

  // "Function Section" § 3.5
  SPECTREPRO_KEY_ESCAPE,
  SPECTREPRO_KEY_F1,
  SPECTREPRO_KEY_F2,
  SPECTREPRO_KEY_F3,
  SPECTREPRO_KEY_F4,
  SPECTREPRO_KEY_F5,
  SPECTREPRO_KEY_F6,
  SPECTREPRO_KEY_F7,
  SPECTREPRO_KEY_F8,
  SPECTREPRO_KEY_F9,
  SPECTREPRO_KEY_F10,
  SPECTREPRO_KEY_F11,
  SPECTREPRO_KEY_F12,
  SPECTREPRO_KEY_F13,
  SPECTREPRO_KEY_F14,
  SPECTREPRO_KEY_F15,
  SPECTREPRO_KEY_F16,
  SPECTREPRO_KEY_F17,
  SPECTREPRO_KEY_F18,
  SPECTREPRO_KEY_F19,
  SPECTREPRO_KEY_F20,
  SPECTREPRO_KEY_F21,
  SPECTREPRO_KEY_F22,
  SPECTREPRO_KEY_F23,
  SPECTREPRO_KEY_F24,
  SPECTREPRO_KEY_F25,
  SPECTREPRO_KEY_FN,
  SPECTREPRO_KEY_FN_LOCK,
  SPECTREPRO_KEY_PRINT_SCREEN,
  SPECTREPRO_KEY_SCROLL_LOCK,
  SPECTREPRO_KEY_PAUSE,

  // "Media Keys" § 3.6
  SPECTREPRO_KEY_BROWSER_BACK,
  SPECTREPRO_KEY_BROWSER_FAVORITES,
  SPECTREPRO_KEY_BROWSER_FORWARD,
  SPECTREPRO_KEY_BROWSER_HOME,
  SPECTREPRO_KEY_BROWSER_REFRESH,
  SPECTREPRO_KEY_BROWSER_SEARCH,
  SPECTREPRO_KEY_BROWSER_STOP,
  SPECTREPRO_KEY_EJECT,
  SPECTREPRO_KEY_LAUNCH_APP_1,
  SPECTREPRO_KEY_LAUNCH_APP_2,
  SPECTREPRO_KEY_LAUNCH_MAIL,
  SPECTREPRO_KEY_MEDIA_PLAY_PAUSE,
  SPECTREPRO_KEY_MEDIA_SELECT,
  SPECTREPRO_KEY_MEDIA_STOP,
  SPECTREPRO_KEY_MEDIA_TRACK_NEXT,
  SPECTREPRO_KEY_MEDIA_TRACK_PREVIOUS,
  SPECTREPRO_KEY_POWER,
  SPECTREPRO_KEY_SLEEP,
  SPECTREPRO_KEY_AUDIO_VOLUME_DOWN,
  SPECTREPRO_KEY_AUDIO_VOLUME_MUTE,
  SPECTREPRO_KEY_AUDIO_VOLUME_UP,
  SPECTREPRO_KEY_WAKE_UP,

  // "Legacy, Non-standard, and Special Keys" § 3.7
  SPECTREPRO_KEY_COPY,
  SPECTREPRO_KEY_CUT,
  SPECTREPRO_KEY_PASTE,
} spectrepro_input_key_e;

typedef struct {
  spectrepro_input_action_e action;
  spectrepro_input_mods_e mods;
  spectrepro_input_mods_e consumed_mods;
  uint32_t keycode;
  const char* text;
  uint32_t unshifted_codepoint;
  bool composing;
} spectrepro_input_key_s;

typedef enum {
  SPECTREPRO_TRIGGER_PHYSICAL,
  SPECTREPRO_TRIGGER_UNICODE,
  SPECTREPRO_TRIGGER_CATCH_ALL,
} spectrepro_input_trigger_tag_e;

typedef union {
  spectrepro_input_key_e physical;
  uint32_t unicode;
  // catch_all has no payload
} spectrepro_input_trigger_key_u;

typedef struct {
  spectrepro_input_trigger_tag_e tag;
  spectrepro_input_trigger_key_u key;
  spectrepro_input_mods_e mods;
} spectrepro_input_trigger_s;

typedef struct {
  const char* action_key;
  const char* action;
  const char* title;
  const char* description;
} spectrepro_command_s;

typedef enum {
  SPECTREPRO_BUILD_MODE_DEBUG,
  SPECTREPRO_BUILD_MODE_RELEASE_SAFE,
  SPECTREPRO_BUILD_MODE_RELEASE_FAST,
  SPECTREPRO_BUILD_MODE_RELEASE_SMALL,
} spectrepro_build_mode_e;

typedef struct {
  spectrepro_build_mode_e build_mode;
  const char* version;
  uintptr_t version_len;
} spectrepro_info_s;

typedef struct {
  const char* message;
} spectrepro_diagnostic_s;

typedef struct {
  const char* ptr;
  uintptr_t len;
  bool sentinel;
} spectrepro_string_s;

typedef struct {
  double tl_px_x;
  double tl_px_y;
  uint32_t offset_start;
  uint32_t offset_len;
  const char* text;
  uintptr_t text_len;
} spectrepro_text_s;

typedef enum {
  SPECTREPRO_POINT_ACTIVE,
  SPECTREPRO_POINT_VIEWPORT,
  SPECTREPRO_POINT_SCREEN,
  SPECTREPRO_POINT_SURFACE,
} spectrepro_point_tag_e;

typedef enum {
  SPECTREPRO_POINT_COORD_EXACT,
  SPECTREPRO_POINT_COORD_TOP_LEFT,
  SPECTREPRO_POINT_COORD_BOTTOM_RIGHT,
} spectrepro_point_coord_e;

typedef struct {
  spectrepro_point_tag_e tag;
  spectrepro_point_coord_e coord;
  uint32_t x;
  uint32_t y;
} spectrepro_point_s;

typedef struct {
  spectrepro_point_s top_left;
  spectrepro_point_s bottom_right;
  bool rectangle;
} spectrepro_selection_s;

typedef struct {
  const char* key;
  const char* value;
} spectrepro_env_var_s;

typedef struct {
  void* nsview;
} spectrepro_platform_macos_s;

typedef struct {
  void* uiview;
} spectrepro_platform_ios_s;

typedef union {
  spectrepro_platform_macos_s macos;
  spectrepro_platform_ios_s ios;
} spectrepro_platform_u;

typedef enum {
  SPECTREPRO_SURFACE_CONTEXT_WINDOW = 0,
  SPECTREPRO_SURFACE_CONTEXT_TAB = 1,
  SPECTREPRO_SURFACE_CONTEXT_SPLIT = 2,
} spectrepro_surface_context_e;

typedef struct {
  spectrepro_platform_e platform_tag;
  spectrepro_platform_u platform;
  void* userdata;
  double scale_factor;
  float font_size;
  const char* working_directory;
  const char* command;
  spectrepro_env_var_s* env_vars;
  size_t env_var_count;
  const char* initial_input;
  bool wait_after_command;
  spectrepro_surface_context_e context;
} spectrepro_surface_config_s;

typedef struct {
  uint16_t columns;
  uint16_t rows;
  uint32_t width_px;
  uint32_t height_px;
  uint32_t cell_width_px;
  uint32_t cell_height_px;
} spectrepro_surface_size_s;

// Config types

// config.Path
typedef struct {
  const char* path;
  bool optional;
} spectrepro_config_path_s;

// config.Color
typedef struct {
  uint8_t r;
  uint8_t g;
  uint8_t b;
} spectrepro_config_color_s;

// config.ColorList
typedef struct {
  const spectrepro_config_color_s* colors;
  size_t len;
} spectrepro_config_color_list_s;

// config.RepeatableCommand
typedef struct {
  const spectrepro_command_s* commands;
  size_t len;
} spectrepro_config_command_list_s;

typedef struct {
  const char* title;
  const char* command;
  const char* group;
  bool execute;
} spectrepro_quick_command_s;

typedef struct {
  const spectrepro_quick_command_s* commands;
  size_t len;
} spectrepro_config_quick_command_list_s;

// config.Palette
typedef struct {
  spectrepro_config_color_s colors[256];
} spectrepro_config_palette_s;

// config.QuickTerminalSize
typedef enum {
  SPECTREPRO_QUICK_TERMINAL_SIZE_NONE,
  SPECTREPRO_QUICK_TERMINAL_SIZE_PERCENTAGE,
  SPECTREPRO_QUICK_TERMINAL_SIZE_PIXELS,
} spectrepro_quick_terminal_size_tag_e;

typedef union {
  float percentage;
  uint32_t pixels;
} spectrepro_quick_terminal_size_value_u;

typedef struct {
  spectrepro_quick_terminal_size_tag_e tag;
  spectrepro_quick_terminal_size_value_u value;
} spectrepro_quick_terminal_size_s;

typedef struct {
  spectrepro_quick_terminal_size_s primary;
  spectrepro_quick_terminal_size_s secondary;
} spectrepro_config_quick_terminal_size_s;

// config.Fullscreen
typedef enum {
  SPECTREPRO_CONFIG_FULLSCREEN_FALSE,
  SPECTREPRO_CONFIG_FULLSCREEN_TRUE,
  SPECTREPRO_CONFIG_FULLSCREEN_NON_NATIVE,
  SPECTREPRO_CONFIG_FULLSCREEN_NON_NATIVE_VISIBLE_MENU,
  SPECTREPRO_CONFIG_FULLSCREEN_NON_NATIVE_PADDED_NOTCH,
} spectrepro_config_fullscreen_e;

// apprt.Target.Key
typedef enum {
  SPECTREPRO_TARGET_APP,
  SPECTREPRO_TARGET_SURFACE,
} spectrepro_target_tag_e;

typedef union {
  spectrepro_surface_t surface;
} spectrepro_target_u;

typedef struct {
  spectrepro_target_tag_e tag;
  spectrepro_target_u target;
} spectrepro_target_s;

// apprt.action.SplitDirection
typedef enum {
  SPECTREPRO_SPLIT_DIRECTION_RIGHT,
  SPECTREPRO_SPLIT_DIRECTION_DOWN,
  SPECTREPRO_SPLIT_DIRECTION_LEFT,
  SPECTREPRO_SPLIT_DIRECTION_UP,
} spectrepro_action_split_direction_e;

// apprt.action.GotoSplit
typedef enum {
  SPECTREPRO_GOTO_SPLIT_PREVIOUS,
  SPECTREPRO_GOTO_SPLIT_NEXT,
  SPECTREPRO_GOTO_SPLIT_UP,
  SPECTREPRO_GOTO_SPLIT_LEFT,
  SPECTREPRO_GOTO_SPLIT_DOWN,
  SPECTREPRO_GOTO_SPLIT_RIGHT,
} spectrepro_action_goto_split_e;

// apprt.action.GotoWindow
typedef enum {
  SPECTREPRO_GOTO_WINDOW_PREVIOUS,
  SPECTREPRO_GOTO_WINDOW_NEXT,
} spectrepro_action_goto_window_e;

// apprt.action.ResizeSplit.Direction
typedef enum {
  SPECTREPRO_RESIZE_SPLIT_UP,
  SPECTREPRO_RESIZE_SPLIT_DOWN,
  SPECTREPRO_RESIZE_SPLIT_LEFT,
  SPECTREPRO_RESIZE_SPLIT_RIGHT,
} spectrepro_action_resize_split_direction_e;

// apprt.action.ResizeSplit
typedef struct {
  uint16_t amount;
  spectrepro_action_resize_split_direction_e direction;
} spectrepro_action_resize_split_s;

// apprt.action.MoveTab
typedef struct {
  ssize_t amount;
} spectrepro_action_move_tab_s;

// apprt.action.GotoTab
typedef enum {
  SPECTREPRO_GOTO_TAB_PREVIOUS = -1,
  SPECTREPRO_GOTO_TAB_NEXT = -2,
  SPECTREPRO_GOTO_TAB_LAST = -3,
} spectrepro_action_goto_tab_e;

// apprt.action.Fullscreen
typedef enum {
  SPECTREPRO_FULLSCREEN_NATIVE,
  SPECTREPRO_FULLSCREEN_MACOS_NON_NATIVE,
  SPECTREPRO_FULLSCREEN_MACOS_NON_NATIVE_VISIBLE_MENU,
  SPECTREPRO_FULLSCREEN_MACOS_NON_NATIVE_PADDED_NOTCH,
} spectrepro_action_fullscreen_e;

// apprt.action.FloatWindow
typedef enum {
  SPECTREPRO_FLOAT_WINDOW_ON,
  SPECTREPRO_FLOAT_WINDOW_OFF,
  SPECTREPRO_FLOAT_WINDOW_TOGGLE,
} spectrepro_action_float_window_e;

// apprt.action.SecureInput
typedef enum {
  SPECTREPRO_SECURE_INPUT_ON,
  SPECTREPRO_SECURE_INPUT_OFF,
  SPECTREPRO_SECURE_INPUT_TOGGLE,
} spectrepro_action_secure_input_e;

// apprt.action.Inspector
typedef enum {
  SPECTREPRO_INSPECTOR_TOGGLE,
  SPECTREPRO_INSPECTOR_SHOW,
  SPECTREPRO_INSPECTOR_HIDE,
} spectrepro_action_inspector_e;

// apprt.action.ExportTerminalIO.C
typedef struct {
  const char* contents;
  size_t len;
} spectrepro_action_export_terminal_io_s;

// apprt.action.QuitTimer
typedef enum {
  SPECTREPRO_QUIT_TIMER_START,
  SPECTREPRO_QUIT_TIMER_STOP,
} spectrepro_action_quit_timer_e;

// apprt.action.Readonly
typedef enum {
  SPECTREPRO_READONLY_OFF,
  SPECTREPRO_READONLY_ON,
} spectrepro_action_readonly_e;

// apprt.action.DesktopNotification.C
typedef struct {
  const char* title;
  const char* body;
} spectrepro_action_desktop_notification_s;

// apprt.action.SetTitle.C
typedef struct {
  const char* title;
} spectrepro_action_set_title_s;

// apprt.action.PromptTitle
typedef enum {
  SPECTREPRO_PROMPT_TITLE_SURFACE,
  SPECTREPRO_PROMPT_TITLE_TAB,
  SPECTREPRO_PROMPT_TITLE_WINDOW,
} spectrepro_action_prompt_title_e;

// apprt.action.Pwd.C
typedef struct {
  const char* pwd;
} spectrepro_action_pwd_s;

// apprt.action.OpenConfig
typedef enum {
  // Open the config in the OS default editor.
  SPECTREPRO_ACTION_OPEN_CONFIG_OS_OPEN,
  // Open the config in a new window using $EDITOR or $VISUAL
  SPECTREPRO_ACTION_OPEN_CONFIG_NEW_WINDOW,
} spectrepro_action_open_config_e;

// terminal.MouseShape
typedef enum {
  SPECTREPRO_MOUSE_SHAPE_DEFAULT,
  SPECTREPRO_MOUSE_SHAPE_CONTEXT_MENU,
  SPECTREPRO_MOUSE_SHAPE_HELP,
  SPECTREPRO_MOUSE_SHAPE_POINTER,
  SPECTREPRO_MOUSE_SHAPE_PROGRESS,
  SPECTREPRO_MOUSE_SHAPE_WAIT,
  SPECTREPRO_MOUSE_SHAPE_CELL,
  SPECTREPRO_MOUSE_SHAPE_CROSSHAIR,
  SPECTREPRO_MOUSE_SHAPE_TEXT,
  SPECTREPRO_MOUSE_SHAPE_VERTICAL_TEXT,
  SPECTREPRO_MOUSE_SHAPE_ALIAS,
  SPECTREPRO_MOUSE_SHAPE_COPY,
  SPECTREPRO_MOUSE_SHAPE_MOVE,
  SPECTREPRO_MOUSE_SHAPE_NO_DROP,
  SPECTREPRO_MOUSE_SHAPE_NOT_ALLOWED,
  SPECTREPRO_MOUSE_SHAPE_GRAB,
  SPECTREPRO_MOUSE_SHAPE_GRABBING,
  SPECTREPRO_MOUSE_SHAPE_ALL_SCROLL,
  SPECTREPRO_MOUSE_SHAPE_COL_RESIZE,
  SPECTREPRO_MOUSE_SHAPE_ROW_RESIZE,
  SPECTREPRO_MOUSE_SHAPE_N_RESIZE,
  SPECTREPRO_MOUSE_SHAPE_E_RESIZE,
  SPECTREPRO_MOUSE_SHAPE_S_RESIZE,
  SPECTREPRO_MOUSE_SHAPE_W_RESIZE,
  SPECTREPRO_MOUSE_SHAPE_NE_RESIZE,
  SPECTREPRO_MOUSE_SHAPE_NW_RESIZE,
  SPECTREPRO_MOUSE_SHAPE_SE_RESIZE,
  SPECTREPRO_MOUSE_SHAPE_SW_RESIZE,
  SPECTREPRO_MOUSE_SHAPE_EW_RESIZE,
  SPECTREPRO_MOUSE_SHAPE_NS_RESIZE,
  SPECTREPRO_MOUSE_SHAPE_NESW_RESIZE,
  SPECTREPRO_MOUSE_SHAPE_NWSE_RESIZE,
  SPECTREPRO_MOUSE_SHAPE_ZOOM_IN,
  SPECTREPRO_MOUSE_SHAPE_ZOOM_OUT,
} spectrepro_action_mouse_shape_e;

// apprt.action.MouseVisibility
typedef enum {
  SPECTREPRO_MOUSE_VISIBLE,
  SPECTREPRO_MOUSE_HIDDEN,
} spectrepro_action_mouse_visibility_e;

// apprt.action.MouseOverLink
typedef struct {
  const char* url;
  size_t len;
} spectrepro_action_mouse_over_link_s;

// apprt.action.SizeLimit
typedef struct {
  uint32_t min_width;
  uint32_t min_height;
  uint32_t max_width;
  uint32_t max_height;
} spectrepro_action_size_limit_s;

// apprt.action.InitialSize
typedef struct {
  uint32_t width;
  uint32_t height;
} spectrepro_action_initial_size_s;

// apprt.action.CellSize
typedef struct {
  uint32_t width;
  uint32_t height;
} spectrepro_action_cell_size_s;

// renderer.Health
typedef enum {
  SPECTREPRO_RENDERER_HEALTH_HEALTHY,
  SPECTREPRO_RENDERER_HEALTH_UNHEALTHY,
} spectrepro_action_renderer_health_e;

// apprt.action.KeySequence
typedef struct {
  bool active;
  spectrepro_input_trigger_s trigger;
} spectrepro_action_key_sequence_s;

// apprt.action.KeyTable.Tag
typedef enum {
  SPECTREPRO_KEY_TABLE_ACTIVATE,
  SPECTREPRO_KEY_TABLE_DEACTIVATE,
  SPECTREPRO_KEY_TABLE_DEACTIVATE_ALL,
} spectrepro_action_key_table_tag_e;

// apprt.action.KeyTable.CValue
typedef union {
  struct {
    const char *name;
    size_t len;
  } activate;
} spectrepro_action_key_table_u;

// apprt.action.KeyTable.C
typedef struct {
  spectrepro_action_key_table_tag_e tag;
  spectrepro_action_key_table_u value;
} spectrepro_action_key_table_s;

// apprt.action.ColorKind
typedef enum {
  SPECTREPRO_ACTION_COLOR_KIND_FOREGROUND = -1,
  SPECTREPRO_ACTION_COLOR_KIND_BACKGROUND = -2,
  SPECTREPRO_ACTION_COLOR_KIND_CURSOR = -3,
} spectrepro_action_color_kind_e;

// apprt.action.ColorChange
typedef struct {
  spectrepro_action_color_kind_e kind;
  uint8_t r;
  uint8_t g;
  uint8_t b;
} spectrepro_action_color_change_s;

// apprt.action.ConfigChange
typedef struct {
  spectrepro_config_t config;
} spectrepro_action_config_change_s;

// apprt.action.ReloadConfig
typedef struct {
  bool soft;
} spectrepro_action_reload_config_s;

// apprt.action.OpenUrlKind
typedef enum {
  SPECTREPRO_ACTION_OPEN_URL_KIND_UNKNOWN,
  SPECTREPRO_ACTION_OPEN_URL_KIND_TEXT,
  SPECTREPRO_ACTION_OPEN_URL_KIND_HTML,
  SPECTREPRO_ACTION_OPEN_URL_KIND_OSC8,
} spectrepro_action_open_url_kind_e;

// apprt.action.OpenUrl.C
typedef struct {
  spectrepro_action_open_url_kind_e kind;
  const char* url;
  uintptr_t len;
} spectrepro_action_open_url_s;

// apprt.action.CloseTabMode
typedef enum {
  SPECTREPRO_ACTION_CLOSE_TAB_MODE_THIS,
  SPECTREPRO_ACTION_CLOSE_TAB_MODE_OTHER,
  SPECTREPRO_ACTION_CLOSE_TAB_MODE_RIGHT,
} spectrepro_action_close_tab_mode_e;

// apprt.surface.Message.ChildExited
typedef struct {
  uint32_t exit_code;
  uint64_t timetime_ms;
} spectrepro_surface_message_childexited_s;

// terminal.osc.Command.ProgressReport.State
typedef enum {
  SPECTREPRO_PROGRESS_STATE_REMOVE,
  SPECTREPRO_PROGRESS_STATE_SET,
  SPECTREPRO_PROGRESS_STATE_ERROR,
  SPECTREPRO_PROGRESS_STATE_INDETERMINATE,
  SPECTREPRO_PROGRESS_STATE_PAUSE,
} spectrepro_action_progress_report_state_e;

// terminal.osc.Command.ProgressReport.C
typedef struct {
  spectrepro_action_progress_report_state_e state;
  // -1 if no progress was reported, otherwise 0-100 indicating percent
  // completeness.
  int8_t progress;
} spectrepro_action_progress_report_s;

// apprt.action.CommandFinished.C
typedef struct {
  // -1 if no exit code was reported, otherwise 0-255
  int16_t exit_code;
  // number of nanoseconds that command was running for
  uint64_t duration;
} spectrepro_action_command_finished_s;

// apprt.action.StartSearch.C
typedef struct {
  const char* needle;
} spectrepro_action_start_search_s;

// apprt.action.SearchTotal
typedef struct {
  ssize_t total;
} spectrepro_action_search_total_s;

// apprt.action.SearchSelected
typedef struct {
  ssize_t selected;
} spectrepro_action_search_selected_s;

// terminal.Scrollbar
typedef struct {
  uint64_t total;
  uint64_t offset;
  uint64_t len;
} spectrepro_action_scrollbar_s;

// apprt.Action.Key
typedef enum {
  SPECTREPRO_ACTION_QUIT,
  SPECTREPRO_ACTION_NEW_WINDOW,
  SPECTREPRO_ACTION_NEW_TAB,
  SPECTREPRO_ACTION_CLOSE_TAB,
  SPECTREPRO_ACTION_NEW_SPLIT,
  SPECTREPRO_ACTION_CLOSE_ALL_WINDOWS,
  SPECTREPRO_ACTION_TOGGLE_MAXIMIZE,
  SPECTREPRO_ACTION_TOGGLE_FULLSCREEN,
  SPECTREPRO_ACTION_TOGGLE_TAB_OVERVIEW,
  SPECTREPRO_ACTION_TOGGLE_WINDOW_DECORATIONS,
  SPECTREPRO_ACTION_TOGGLE_QUICK_TERMINAL,
  SPECTREPRO_ACTION_TOGGLE_COMMAND_PALETTE,
  SPECTREPRO_ACTION_TOGGLE_VISIBILITY,
  SPECTREPRO_ACTION_TOGGLE_BACKGROUND_OPACITY,
  SPECTREPRO_ACTION_MOVE_TAB,
  SPECTREPRO_ACTION_GOTO_TAB,
  SPECTREPRO_ACTION_GOTO_SPLIT,
  SPECTREPRO_ACTION_GOTO_WINDOW,
  SPECTREPRO_ACTION_RESIZE_SPLIT,
  SPECTREPRO_ACTION_EQUALIZE_SPLITS,
  SPECTREPRO_ACTION_TOGGLE_SPLIT_ZOOM,
  SPECTREPRO_ACTION_PRESENT_TERMINAL,
  SPECTREPRO_ACTION_SIZE_LIMIT,
  SPECTREPRO_ACTION_RESET_WINDOW_SIZE,
  SPECTREPRO_ACTION_INITIAL_SIZE,
  SPECTREPRO_ACTION_CELL_SIZE,
  SPECTREPRO_ACTION_SCROLLBAR,
  SPECTREPRO_ACTION_RENDER,
  SPECTREPRO_ACTION_INSPECTOR,
  SPECTREPRO_ACTION_SHOW_GTK_INSPECTOR,
  SPECTREPRO_ACTION_RENDER_INSPECTOR,
  SPECTREPRO_ACTION_EXPORT_TERMINAL_IO,
  SPECTREPRO_ACTION_DESKTOP_NOTIFICATION,
  SPECTREPRO_ACTION_SET_TITLE,
  SPECTREPRO_ACTION_SET_TAB_TITLE,
  SPECTREPRO_ACTION_SET_WINDOW_TITLE,
  SPECTREPRO_ACTION_PROMPT_TITLE,
  SPECTREPRO_ACTION_PWD,
  SPECTREPRO_ACTION_MOUSE_SHAPE,
  SPECTREPRO_ACTION_MOUSE_VISIBILITY,
  SPECTREPRO_ACTION_MOUSE_OVER_LINK,
  SPECTREPRO_ACTION_RENDERER_HEALTH,
  SPECTREPRO_ACTION_OPEN_CONFIG,
  SPECTREPRO_ACTION_QUIT_TIMER,
  SPECTREPRO_ACTION_FLOAT_WINDOW,
  SPECTREPRO_ACTION_SECURE_INPUT,
  SPECTREPRO_ACTION_KEY_SEQUENCE,
  SPECTREPRO_ACTION_KEY_TABLE,
  SPECTREPRO_ACTION_COLOR_CHANGE,
  SPECTREPRO_ACTION_RELOAD_CONFIG,
  SPECTREPRO_ACTION_CONFIG_CHANGE,
  SPECTREPRO_ACTION_CLOSE_WINDOW,
  SPECTREPRO_ACTION_RING_BELL,
  SPECTREPRO_ACTION_SELECTION_CHANGED,
  SPECTREPRO_ACTION_UNDO,
  SPECTREPRO_ACTION_REDO,
  SPECTREPRO_ACTION_CHECK_FOR_UPDATES,
  SPECTREPRO_ACTION_OPEN_URL,
  SPECTREPRO_ACTION_SHOW_CHILD_EXITED,
  SPECTREPRO_ACTION_PROGRESS_REPORT,
  SPECTREPRO_ACTION_SHOW_ON_SCREEN_KEYBOARD,
  SPECTREPRO_ACTION_COMMAND_FINISHED,
  SPECTREPRO_ACTION_START_SEARCH,
  SPECTREPRO_ACTION_END_SEARCH,
  SPECTREPRO_ACTION_SEARCH_TOTAL,
  SPECTREPRO_ACTION_SEARCH_SELECTED,
  SPECTREPRO_ACTION_READONLY,
  SPECTREPRO_ACTION_COPY_TITLE_TO_CLIPBOARD,
  SPECTREPRO_ACTION_MOVE_TAB_TO_NEW_WINDOW,
  SPECTREPRO_ACTION_TOGGLE_QUICK_COMMANDS,
} spectrepro_action_tag_e;

typedef union {
  spectrepro_action_split_direction_e new_split;
  spectrepro_action_fullscreen_e toggle_fullscreen;
  spectrepro_action_move_tab_s move_tab;
  spectrepro_action_goto_tab_e goto_tab;
  spectrepro_action_goto_split_e goto_split;
  spectrepro_action_goto_window_e goto_window;
  spectrepro_action_resize_split_s resize_split;
  spectrepro_action_size_limit_s size_limit;
  spectrepro_action_initial_size_s initial_size;
  spectrepro_action_cell_size_s cell_size;
  spectrepro_action_scrollbar_s scrollbar;
  spectrepro_action_inspector_e inspector;
  spectrepro_action_export_terminal_io_s export_terminal_io;
  spectrepro_action_desktop_notification_s desktop_notification;
  spectrepro_action_set_title_s set_title;
  spectrepro_action_set_title_s set_tab_title;
  spectrepro_action_prompt_title_e prompt_title;
  spectrepro_action_pwd_s pwd;
  spectrepro_action_mouse_shape_e mouse_shape;
  spectrepro_action_mouse_visibility_e mouse_visibility;
  spectrepro_action_mouse_over_link_s mouse_over_link;
  spectrepro_action_renderer_health_e renderer_health;
  spectrepro_action_quit_timer_e quit_timer;
  spectrepro_action_float_window_e float_window;
  spectrepro_action_secure_input_e secure_input;
  spectrepro_action_key_sequence_s key_sequence;
  spectrepro_action_key_table_s key_table;
  spectrepro_action_color_change_s color_change;
  spectrepro_action_reload_config_s reload_config;
  spectrepro_action_config_change_s config_change;
  spectrepro_action_open_url_s open_url;
  spectrepro_action_close_tab_mode_e close_tab_mode;
  spectrepro_surface_message_childexited_s child_exited;
  spectrepro_action_progress_report_s progress_report;
  spectrepro_action_command_finished_s command_finished;
  spectrepro_action_start_search_s start_search;
  spectrepro_action_search_total_s search_total;
  spectrepro_action_search_selected_s search_selected;
  spectrepro_action_readonly_e readonly;
  spectrepro_action_open_config_e open_config;
} spectrepro_action_u;

typedef struct {
  spectrepro_action_tag_e tag;
  spectrepro_action_u action;
} spectrepro_action_s;

typedef void (*spectrepro_runtime_wakeup_cb)(void*);
typedef spectrepro_clipboard_read_result_e (*spectrepro_runtime_read_clipboard_cb)(
    void*,
    spectrepro_clipboard_e,
    void*,
    const char* const*,
    size_t,
    bool);
typedef void (*spectrepro_runtime_confirm_read_clipboard_cb)(
    void*,
    const spectrepro_clipboard_confirm_s*,
    void*,
    spectrepro_clipboard_request_e);
typedef void (*spectrepro_runtime_write_clipboard_cb)(void*,
                                                   spectrepro_clipboard_e,
                                                   const spectrepro_clipboard_content_s*,
                                                   size_t,
                                                   bool);
typedef void (*spectrepro_runtime_close_surface_cb)(void*, bool);
typedef bool (*spectrepro_runtime_action_cb)(spectrepro_app_t,
                                          spectrepro_target_s,
                                          spectrepro_action_s);

typedef struct {
  void* userdata;
  bool supports_selection_clipboard;
  spectrepro_runtime_wakeup_cb wakeup_cb;
  spectrepro_runtime_action_cb action_cb;
  spectrepro_runtime_read_clipboard_cb read_clipboard_cb;
  spectrepro_runtime_confirm_read_clipboard_cb confirm_read_clipboard_cb;
  spectrepro_runtime_write_clipboard_cb write_clipboard_cb;
  spectrepro_runtime_close_surface_cb close_surface_cb;
} spectrepro_runtime_config_s;

// apprt.ipc.Target.Key
typedef enum {
  SPECTREPRO_IPC_TARGET_CLASS,
  SPECTREPRO_IPC_TARGET_DETECT,
} spectrepro_ipc_target_tag_e;

typedef union {
  char *klass;
} spectrepro_ipc_target_u;

typedef struct {
  spectrepro_ipc_target_tag_e tag;
  spectrepro_ipc_target_u target;
} chostty_ipc_target_s;

// apprt.ipc.Action.NewWindow
typedef struct {
  // This should be a null terminated list of strings.
  const char **arguments;
} spectrepro_ipc_action_new_window_s;

typedef union {
  spectrepro_ipc_action_new_window_s new_window;
} spectrepro_ipc_action_u;

// apprt.ipc.Action.Key
typedef enum {
  SPECTREPRO_IPC_ACTION_NEW_WINDOW,
  SPECTREPRO_IPC_ACTION_NEW_TAB,
  SPECTREPRO_IPC_ACTION_TOGGLE_QUICK_TERMINAL,
} spectrepro_ipc_action_tag_e;

//-------------------------------------------------------------------
// Published API

SPECTREPRO_API int spectrepro_init(uintptr_t, char**);
SPECTREPRO_API void spectrepro_cli_try_action(void);
SPECTREPRO_API spectrepro_info_s spectrepro_info(void);
SPECTREPRO_API const char* spectrepro_translate(const char*);
SPECTREPRO_API void spectrepro_string_free(spectrepro_string_s);

SPECTREPRO_API spectrepro_config_t spectrepro_config_new();
SPECTREPRO_API void spectrepro_config_free(spectrepro_config_t);
SPECTREPRO_API spectrepro_config_t spectrepro_config_clone(spectrepro_config_t);
SPECTREPRO_API void spectrepro_config_load_cli_args(spectrepro_config_t);
SPECTREPRO_API void spectrepro_config_load_file(spectrepro_config_t, const char*);
SPECTREPRO_API void spectrepro_config_load_default_files(spectrepro_config_t);
SPECTREPRO_API void spectrepro_config_load_recursive_files(spectrepro_config_t);
SPECTREPRO_API void spectrepro_config_finalize(spectrepro_config_t);
SPECTREPRO_API bool spectrepro_config_get(spectrepro_config_t, void*, const char*, uintptr_t);
SPECTREPRO_API spectrepro_input_trigger_s spectrepro_config_trigger(spectrepro_config_t,
                                                              const char*,
                                                              uintptr_t);
SPECTREPRO_API bool spectrepro_config_key_is_binding(spectrepro_config_t, spectrepro_input_key_s);
SPECTREPRO_API uint32_t spectrepro_config_diagnostics_count(spectrepro_config_t);
SPECTREPRO_API spectrepro_diagnostic_s spectrepro_config_get_diagnostic(spectrepro_config_t, uint32_t);
SPECTREPRO_API spectrepro_string_s spectrepro_config_open_path(void);

SPECTREPRO_API spectrepro_app_t spectrepro_app_new(const spectrepro_runtime_config_s*,
                                             spectrepro_config_t);
SPECTREPRO_API void spectrepro_app_free(spectrepro_app_t);
SPECTREPRO_API void spectrepro_app_tick(spectrepro_app_t);
SPECTREPRO_API void* spectrepro_app_userdata(spectrepro_app_t);
SPECTREPRO_API void spectrepro_app_set_focus(spectrepro_app_t, bool);
SPECTREPRO_API bool spectrepro_app_key(spectrepro_app_t, spectrepro_input_key_s);
SPECTREPRO_API void spectrepro_app_keyboard_changed(spectrepro_app_t);
SPECTREPRO_API void spectrepro_app_open_config(spectrepro_app_t);
SPECTREPRO_API void spectrepro_app_update_config(spectrepro_app_t, spectrepro_config_t);
SPECTREPRO_API bool spectrepro_app_needs_confirm_quit(spectrepro_app_t);
SPECTREPRO_API bool spectrepro_app_has_global_keybinds(spectrepro_app_t);
SPECTREPRO_API void spectrepro_app_set_color_scheme(spectrepro_app_t, spectrepro_color_scheme_e);

SPECTREPRO_API spectrepro_surface_config_s spectrepro_surface_config_new();

SPECTREPRO_API spectrepro_surface_t spectrepro_surface_new(spectrepro_app_t,
                                                     const spectrepro_surface_config_s*);
SPECTREPRO_API void spectrepro_surface_free(spectrepro_surface_t);
SPECTREPRO_API void* spectrepro_surface_userdata(spectrepro_surface_t);
SPECTREPRO_API spectrepro_app_t spectrepro_surface_app(spectrepro_surface_t);
SPECTREPRO_API spectrepro_surface_config_s spectrepro_surface_inherited_config(spectrepro_surface_t, spectrepro_surface_context_e);
SPECTREPRO_API void spectrepro_surface_update_config(spectrepro_surface_t, spectrepro_config_t);
SPECTREPRO_API bool spectrepro_surface_needs_confirm_quit(spectrepro_surface_t);
SPECTREPRO_API bool spectrepro_surface_process_exited(spectrepro_surface_t);
SPECTREPRO_API void spectrepro_surface_refresh(spectrepro_surface_t);
SPECTREPRO_API void spectrepro_surface_draw(spectrepro_surface_t);
SPECTREPRO_API void spectrepro_surface_set_content_scale(spectrepro_surface_t, double, double);
SPECTREPRO_API void spectrepro_surface_set_focus(spectrepro_surface_t, bool);
SPECTREPRO_API void spectrepro_surface_set_occlusion(spectrepro_surface_t, bool);
SPECTREPRO_API void spectrepro_surface_set_size(spectrepro_surface_t, uint32_t, uint32_t);
SPECTREPRO_API spectrepro_surface_size_s spectrepro_surface_size(spectrepro_surface_t);
SPECTREPRO_API uint64_t spectrepro_surface_foreground_pid(spectrepro_surface_t);
SPECTREPRO_API spectrepro_string_s spectrepro_surface_tty_name(spectrepro_surface_t);
SPECTREPRO_API void spectrepro_surface_set_color_scheme(spectrepro_surface_t,
                                                     spectrepro_color_scheme_e);
SPECTREPRO_API spectrepro_input_mods_e spectrepro_surface_key_translation_mods(spectrepro_surface_t,
                                                                         spectrepro_input_mods_e);
SPECTREPRO_API bool spectrepro_surface_key(spectrepro_surface_t, spectrepro_input_key_s);
SPECTREPRO_API bool spectrepro_surface_key_is_binding(spectrepro_surface_t,
                                                   spectrepro_input_key_s,
                                                   spectrepro_binding_flags_e*);
SPECTREPRO_API void spectrepro_surface_text(spectrepro_surface_t, const char*, uintptr_t);
SPECTREPRO_API void spectrepro_surface_preedit(spectrepro_surface_t, const char*, uintptr_t);
SPECTREPRO_API bool spectrepro_surface_mouse_captured(spectrepro_surface_t);
SPECTREPRO_API bool spectrepro_surface_mouse_button(spectrepro_surface_t,
                                                 spectrepro_input_mouse_state_e,
                                                 spectrepro_input_mouse_button_e,
                                                 spectrepro_input_mods_e);
SPECTREPRO_API void spectrepro_surface_mouse_pos(spectrepro_surface_t,
                                              double,
                                              double,
                                              spectrepro_input_mods_e);
SPECTREPRO_API void spectrepro_surface_mouse_scroll(spectrepro_surface_t,
                                                 double,
                                                 double,
                                                 spectrepro_input_scroll_mods_t);
SPECTREPRO_API void spectrepro_surface_mouse_pressure(spectrepro_surface_t, uint32_t, double);
SPECTREPRO_API void spectrepro_surface_ime_point(spectrepro_surface_t, double*, double*, double*, double*);
SPECTREPRO_API void spectrepro_surface_request_close(spectrepro_surface_t);
SPECTREPRO_API void spectrepro_surface_split(spectrepro_surface_t, spectrepro_action_split_direction_e);
SPECTREPRO_API void spectrepro_surface_split_focus(spectrepro_surface_t,
                                                spectrepro_action_goto_split_e);
SPECTREPRO_API void spectrepro_surface_split_resize(spectrepro_surface_t,
                                                 spectrepro_action_resize_split_direction_e,
                                                 uint16_t);
SPECTREPRO_API void spectrepro_surface_split_equalize(spectrepro_surface_t);
SPECTREPRO_API bool spectrepro_surface_binding_action(spectrepro_surface_t, const char*, uintptr_t);
SPECTREPRO_API void spectrepro_surface_complete_clipboard_request(
    spectrepro_surface_t,
    const spectrepro_clipboard_complete_s*,
    void*);
SPECTREPRO_API void spectrepro_surface_deny_clipboard_request(spectrepro_surface_t,
                                                           void*);
SPECTREPRO_API bool spectrepro_surface_has_selection(spectrepro_surface_t);
SPECTREPRO_API bool spectrepro_surface_read_selection(spectrepro_surface_t, spectrepro_text_s*);
SPECTREPRO_API bool spectrepro_surface_read_text(spectrepro_surface_t,
                                              spectrepro_selection_s,
                                              spectrepro_text_s*);
SPECTREPRO_API void spectrepro_surface_free_text(spectrepro_surface_t, spectrepro_text_s*);

#ifdef __APPLE__
SPECTREPRO_API void spectrepro_surface_set_display_id(spectrepro_surface_t, uint32_t);
SPECTREPRO_API void* spectrepro_surface_quicklook_font(spectrepro_surface_t);
SPECTREPRO_API bool spectrepro_surface_quicklook_word(spectrepro_surface_t, spectrepro_text_s*);
#endif

SPECTREPRO_API spectrepro_inspector_t spectrepro_surface_inspector(spectrepro_surface_t);
SPECTREPRO_API void spectrepro_inspector_free(spectrepro_surface_t);
SPECTREPRO_API void spectrepro_inspector_set_focus(spectrepro_inspector_t, bool);
SPECTREPRO_API void spectrepro_inspector_set_content_scale(spectrepro_inspector_t, double, double);
SPECTREPRO_API void spectrepro_inspector_set_size(spectrepro_inspector_t, uint32_t, uint32_t);
SPECTREPRO_API void spectrepro_inspector_mouse_button(spectrepro_inspector_t,
                                                   spectrepro_input_mouse_state_e,
                                                   spectrepro_input_mouse_button_e,
                                                   spectrepro_input_mods_e);
SPECTREPRO_API void spectrepro_inspector_mouse_pos(spectrepro_inspector_t, double, double);
SPECTREPRO_API void spectrepro_inspector_mouse_scroll(spectrepro_inspector_t,
                                                   double,
                                                   double,
                                                   spectrepro_input_scroll_mods_t);
SPECTREPRO_API void spectrepro_inspector_key(spectrepro_inspector_t,
                                          spectrepro_input_action_e,
                                          spectrepro_input_key_e,
                                          spectrepro_input_mods_e);
SPECTREPRO_API void spectrepro_inspector_text(spectrepro_inspector_t, const char*);

#ifdef __APPLE__
SPECTREPRO_API bool spectrepro_inspector_metal_init(spectrepro_inspector_t, void*);
SPECTREPRO_API void spectrepro_inspector_metal_render(spectrepro_inspector_t, void*, void*);
SPECTREPRO_API bool spectrepro_inspector_metal_shutdown(spectrepro_inspector_t);
#endif

// APIs I'd like to get rid of eventually but are still needed for now.
// Don't use these unless you know what you're doing.
SPECTREPRO_API void spectrepro_set_window_background_blur(spectrepro_app_t, void*);

// Benchmark API, if available.
SPECTREPRO_API bool spectrepro_benchmark_cli(const char*, const char*);

#ifdef __cplusplus
}
#endif

#endif /* SPECTREPRO_H */
