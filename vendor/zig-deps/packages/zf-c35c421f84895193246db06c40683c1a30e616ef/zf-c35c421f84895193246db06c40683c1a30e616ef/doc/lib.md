# Using zf as a library

zf is offered as both a Zig module and a C library. zf is allocation free and expects the caller to handle any required allocations.

To add to your project run

```
zig fetch --save git+https://github.com/natecraddock/zf
```

Then in your build.zig file you can use the dependency.

```zig
pub fn build(b: *std.Build) void {
    // ... snip ...

    const ziglua = b.dependency("zf", .{
        .target = target,
        .optimize = optimize,
        .with_tui = false,
    });

    // ... snip ...

    // add the zf module
    exe.root_module.addImport("zf", ziglua.module("zf"));

}
```

In your code zf will be available with `@import("zf")`

See [the source](https://github.com/natecraddock/zf/blob/master/src/zf/zf.zig) for documentation on each function.

## Usage details
**There are a few things that zf expects you to follow when using it as a library**

The zf API is designed to offer maximum performance. This means the API leaves some decisions to the caller like allocation and tokenizing the input query.

### Function types

The library offers functions two types of functions. One that ranks a slice of needles, and one that ranks a single needle:
* `rank()` and `highlight()` rank and highlight a haystack against a slice of needles.
* `rankNeedle()` and `highlightNeedle()` operate on a single needle

### Case sensitivity
Set `case_sensitive` to false to enable case insensitive ranking.

### Plaintext matching
The high-level `rank()` and `highlight()` functions accept a boolean `plain` parameter. When true filename computations are bypassed.

### The `filename` parameter
The `rankNeedle()` and `highlightNeedle` functions accept a filename as a parameter. The filename should be set to null when there is no filename. The reason the library functions do not do this for you is again for efficiency reasons. This would be expensive to compute for each given needle. It is expected that the caller will provide the filename when doing the ranking one needle at a time.

To disable filename matching (for plaintext haystacks or for more efficiency) `null` can be passed as the filename.

### Range highlighting

Range highlighting is provided as a separate function and not done in the ranking. The reason it is a separate function is that range calculations are more expensive to compute. Because the normal case is that only a small portion of all input lines are shown in a UI, ranking is done separately to keep things performant.

This also makes ranking more performant for callers who do not need range highlight information.

## Example

```zig
const std = @import("std");

const zf = @import("zf");

pub fn main() void {
    // Strings we want to rank
    const strings = [_][]const u8{
        "src/tui/EditBuffer.zig",
        "src/tui/Previewer.zig",
        "src/tui/array_toggle_set.zig",
        "src/tui/input.zig",
        "src/tui/main.zig",
        "src/tui/opts.zig",
        "src/tui/ui.zig",
        "src/zf/clib.zig",
        "src/zf/filter.zig",
        "src/zf/zf.zig",
    };

    // Ranking based on a single needle
    const query = "tui";
    for (strings) |str| {
        const rank = zf.rankNeedle(str, query, .{});
        std.debug.print("str: {s} rank: {?}\n", .{ str, rank });
    }

    std.debug.print("\n", .{});

    // Ranking based on multiple needles
    const needles = [_][]const u8{ "tui", "Pr" };
    for (strings) |str| {
        const rank = zf.rank(str, &needles, .{});
        std.debug.print("str: {s} rank: {?}\n", .{ str, rank });
    }
}
```

Look at the zf TUI source code for more examples on how to use the module.

## C

See the source code of [telescipe-zf-native.nvim](https://github.com/natecraddock/telescope-zf-native.nvim) for a good example of
using zf ranking from C.
