const std = @import("std");
const v = @import("vector_types.zig");

pub extern fn w_mm256_shuffle_epi8(a: v.u8x32, b: v.u8x32) v.u8x32;
pub inline fn mm256_shuffle_epi8(a: v.u8x32, b: v.u8x32) v.u8x32 {
    return w_mm256_shuffle_epi8(a, b);
}

test "pshufb" {
    const x = mm256_shuffle_epi8(("a" ** 32).*, ("b" ** 32).*);
    _ = x;
    std.debug.print("x {s}\n", .{@as([32]u8, x)});
}
