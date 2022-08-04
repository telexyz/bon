const std = @import("std");
const v = @import("vector_types.zig");

// 23 âm giữa (âm đệm + nguyên âm)
// 16 middle16 + 7 middle 32

const lookup16 = v.u16x16{
    'a',
    'e',
    'i',
    'o',
    'u',
    'y',
    (@as(u16, 195) << 8) + 162, // 'â'195:162
    (@as(u16, 196) << 8) + 131, // 'ă'196:131
    (@as(u16, 195) << 8) + 170, // 'ê'195:170
    (@as(u16, 195) << 8) + 180, // 'ô'195:180
    (@as(u16, 198) << 8) + 161, // 'ơ'198:161
    (@as(u16, 198) << 8) + 176, // 'ư'198:176
    (@as(u16, 'o') << 8) + 'a',
    (@as(u16, 'o') << 8) + 'e',
    (@as(u16, 'o') << 8) + 'o',
    (@as(u16, 'u') << 8) + 'y',
};
const middle16: []const []const u8 = &.{
    "a", //  01: a
    "e", //  02: e
    "i", //  03: i
    "o", //  04: o
    "u", //  05: u
    "y", //  06: y
    "az", // 07: â
    "aw", // 08: ă
    "ez", // 09: ê
    "oz", // 10: ô
    "ow", // 11: ơ
    "uw", // 12: ư
    "oa", // 13: oa
    "oe", // 14: oe
    "oo", // 15: boong
    "uy", // 16: uy
    "", //   17: _none
};

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
const middle32: []const []const u8 = &.{
    "iez", //  0: iê
    "oaw", //  1: oă (loắt choắt)
    "uaz", //  2: uâ (tuân)
    "uez", //  3: uê (tuềnh toàng)
    "uoz", //  4: uô
    "uwow", // 5: uơ tự convert thành ươ
    "uwow", // 6: ươ
    "uyez", // 7: uyê
    "", //     8: _none
};

pub inline fn getMiddle(c0b0: u8, c0b1: u8, c1b0: u8, c1b1: u8) []const u8 {
    const a = (@intCast(u32, c0b1) << 24) + (@intCast(u32, c0b0) << 16) +
        (@intCast(u32, c1b1) << 8) + c1b0;
    const input32 = v.u32x8{ a, a, a, a, a, a, a, a };
    const match32: u8 = @ptrCast(*const u8, &(input32 == lookup32)).*;
    const pos32: u8 = if (match32 > 0) @ctz(u8, match32) else 8;

    if (pos32 < 8) {
        // std.debug.print("\n\n{x}-{x} {x}-{x}", .{ c0b1, c0b0, c1b1, c1b0 });
        // std.debug.print("\n\n{x:0>8}\n{x:0>8}", .{ input32, lookup32 });
        // std.debug.print("\n\n{b:0>8} {d}\n", .{ match32, pos32 });
        return middle32[pos32];
    } else {
        const b = (@intCast(u16, c0b1) << 8) + c0b0;
        const input16 = v.u16x16{ b, b, b, b, b, b, b, b, b, b, b, b, b, b, b, b };
        const match16: u16 = @ptrCast(*const u16, &(input16 == lookup16)).*;
        const pos16 = if (match16 > 0) @ctz(u16, match16) else 16;

        // const w = [_]u8{ if (c0b1 == 0) 32 else c0b1, c0b0 };
        // std.debug.print("\n\n'{s}'{x}:{x}", .{ w, c0b1, c0b0 });
        // std.debug.print("\n\n{x:0>8}\n{x:0>8}", .{ input16, lookup16 });
        // std.debug.print("\n\n{b:0>8} {d}\n", .{ match16, pos16 });
        return middle16[pos16];
    }
}
