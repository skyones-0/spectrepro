const std = @import("std");

/// Make every field of the struct T nullable.
pub fn Partial(comptime T: type) type {
    const T_info = switch (@typeInfo(T)) {
        .@"struct" => |x| x,
        else => @compileError("Partial only supports struct types for now"),
    };

    const fields = T_info.fields;

    comptime var field_names: [fields.len][]const u8 = undefined;
    comptime var field_types: [fields.len]type = undefined;
    comptime var field_attrs: [fields.len]std.builtin.Type.StructField.Attributes = undefined;

    inline for (fields, 0..) |field, i| {
        field_names[i] = field.name;
        field_types[i] = ?field.type;
        field_attrs[i] = .{
            .@"comptime" = field.is_comptime,
            .@"align" = field.alignment,
            .default_value_ptr = &@as(?field.type, null),
        };
    }

    return @Struct(
        T_info.layout,
        T_info.backing_integer,
        &field_names,
        &field_types,
        &field_attrs,
    );
}

/// Take any non-null fields from x, and any null fields are taken from y
/// instead.
pub fn partial(comptime T: type, x: Partial(T), y: T) T {
    const T_info = switch (@typeInfo(T)) {
        .@"struct" => |info| info,
        else => @compileError("Partial only supports struct types for now"),
    };
    var t: T = undefined;
    inline for (T_info.fields) |f|
        @field(t, f.name) =
            if (@field(x, f.name)) |xx| xx else @field(y, f.name);
    return t;
}

test partial {
    const Foo = struct { abc: u8, xyz: u8 };
    const a: Foo = .{ .abc = 5, .xyz = 10 };
    const b: Foo = partial(Foo, .{ .abc = 6 }, a);
    try std.testing.expectEqual(@as(u8, 6), b.abc);
    try std.testing.expectEqual(@as(u8, 10), b.xyz);
}
