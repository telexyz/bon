const std = @import("std");
const v = @import("vector_types.zig");

pub extern fn w_mm_setr_epi8(v15: u8, v14: u8, v13: u8, v12: u8, v11: u8, v10: u8, v9: u8, v8: u8, v7: u8, v6: u8, v5: u8, v4: u8, v3: u8, v2: u8, v1: u8, v0: u8) v.u8x16;
pub inline fn mm_setr_epi8(v15: u8, v14: u8, v13: u8, v12: u8, v11: u8, v10: u8, v9: u8, v8: u8, v7: u8, v6: u8, v5: u8, v4: u8, v3: u8, v2: u8, v1: u8, v0: u8) v.u8x16 {
    return w_mm_setr_epi8(v15, v14, v13, v12, v11, v10, v9, v8, v7, v6, v5, v4, v3, v2, v1, v0);
}

pub extern fn w_mm256_shuffle_epi8(a: v.u8x32, b: v.u8x32) v.u8x32;
pub inline fn mm256_shuffle_epi8(a: v.u8x32, b: v.u8x32) v.u8x32 {
    return w_mm256_shuffle_epi8(a, b);
}

pub extern fn w_mm_shuffle_epi8(a: v.u8x16, b: v.u8x16) v.u8x16;
pub inline fn mm_shuffle_epi8(a: v.u8x16, b: v.u8x16) v.u8x16 {
    return w_mm_shuffle_epi8(a, b);
}

test "pshufb" {
    const x = mm256_shuffle_epi8(("a" ** 32).*, ("b" ** 32).*);
    std.debug.print("\nx {s}\n", .{@as([32]u8, x)});

    const y = mm_shuffle_epi8(("a" ** 16).*, ("c" ** 16).*);
    std.debug.print("\ny {s}\n", .{@as([16]u8, y)});
}
