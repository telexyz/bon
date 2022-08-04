const std = @import("std");
const v = @import("vector_types.zig");

// 23 âm giữa (âm đệm + nguyên âm)

// 2 x 16 = 32-byte
// 0a, // a
// 0e, // e
// 0i, // i
// 0o, // o
// 0u, // u
// 0y, // y
// az, // â
// aw, // ă
// ez, // ê
// oz, // ô
// ow, // ơ
// uw, // ư
// oa, // oa
// oe, // oe
// oo, // boong
// uy, // uy
// => use `_mm256_cmpeq_epi16`

// 4 x 8 = 32-byte
// 0iez, // iê
// 0oaw, // oă (loắt choắt)
// 0uaz, // uâ (tuân)
// 0uez, // uê (tuềnh toàng)
// 0uoz, // uô
// 0uow, // uơ tự convert thành ươ
// uwow, // ươ
// uyez, // uyê
// => use `_mm256_cmpeq_epi32`

const lookup32 = v.u32x8{
    (@as(u32, 'i') << 16) + (@as(u32, 195) << 8) + 170, // i'ê'195:170
    (@as(u32, 'o') << 16) + (@as(u32, 196) << 8) + 131, // o'ă'196:131
    (@as(u32, 'u') << 16) + (@as(u32, 195) << 8) + 162, // u'â'195:162
    (@as(u32, 'u') << 16) + (@as(u32, 195) << 8) + 170, // u'ê'195:170
    (@as(u32, 'u') << 16) + (@as(u32, 195) << 8) + 180, // u'ô'195:180
    (@as(u32, 'u') << 16) + (@as(u32, 198) << 8) + 161, // 'u'ơ'198:161
    (@as(u32, 198) << 24) + (@as(u32, 176) << 16) + (@as(u32, 198) << 8) + 161, // 'ư'198:176'ơ'
    (@as(u32, 'u') << 24) + (@as(u32, 'y') << 16) + (@as(u32, 195) << 8) + 170, // uy'ê'195:170
};

const middle32: []const []const u8 = &.{ "iez", "oaw", "uaz", "uez", "uoz", "uwow", "uwow", "uyez", "" };

pub inline fn getMiddle(c0b0: u8, c0b1: u8, c1b0: u8, c1b1: u8) []const u8 {
    const a = (@intCast(u32, c0b1) << 24) + (@intCast(u32, c0b0) << 16) +
        (@intCast(u32, c1b1) << 8) + c1b0;

    const input = v.u32x8{ a, a, a, a, a, a, a, a };

    const match: u8 = @ptrCast(*const u8, &(input == lookup32)).*;
    var pos: u8 = 8;
    if (match > 0) {
        pos = @ctz(u8, match);
    }

    // std.debug.print("\n\n{x}-{x} {x}-{x}", .{ c0b1, c0b0, c1b1, c1b0 });
    // std.debug.print("\n\n{x:0>8}\n{x:0>8}", .{ input, lookup32 });
    // std.debug.print("\n\n{b:0>8} {d}\n", .{ match, pos });

    return middle32[pos];
}
