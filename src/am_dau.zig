//! 22 phụ âm: b, c (k,q), ch, d, đ, g (gh), h, kh, l, m, n, nh, ng (ngh),
//! p, ph, r, s, t, tr, th, v, x. (+ qu, gi, _none => 25)
//!
//! TÌM PHỤ ÂM ĐẦU
//! phu_am_don: u8x16 = "bckqdghlmnprstvx"; // 16-bytes
//! phu_am_doi: u16x16 = "chzdghkhngphtrthqugi"; // 20-bytes
//
// http://0x80.pl/notesen/2019-02-03-simd-switch-implementation.html

const std = @import("std");
const v = @import("vector_types.zig");
const simd = @import("simd.zig");

const initials: []const []const u8 = &.{
    "x",  "v",  "s",  "r",  "m",  "l",  "6",  "h", "d",  "b", "10", "11", "g", //
    "gi", "q",  "qu", "18", "tr", "p",  "ph", "n", "ng", "k", "kh", "g",  "gh",
    "0",  "zd", "c",  "ch", "t",  "th", "",
};

const lookup = v.u8x32{
    'x', 'v', 's', 'r', 'm', 'l', '-', 'h', 'd', 'b', '-', '-', //
    'g', 'i', 'q', 'u', 't', 'r', 'p', 'h', 'n', 'g', 'k', 'h',
    'g', 'h', 'z', 'd', 'c', 'h', 't', 'h',
};

const phu_am_don_mask = 0b01010101010101010101001111111111;

pub inline fn getInitial(f: u8, s: u8) []const u8 {
    const a = (@intCast(u16, s) << 8) + f;
    const b = (@intCast(u16, f) << 8) + f;
    const input = simd.set16_m256(a, a, a, a, a, a, a, a, a, a, b, b, b, b, b, b);
    // const input = v.u8x32{
    //     f, f, f, f, f, f, f, f, f, f, f, f, //
    //     f, s, f, s, f, s, f, s, f, s, f, s,
    //     f, s, f, s, f, s, f, s,
    // };

    const match: u32 = @ptrCast(*const u32, &(input == lookup)).*; // Zig Vector `==` op
    const phu_am_doi_match = match << 1 & match;

    var pos: u32 = 32;
    if (phu_am_doi_match > 0) {
        pos = 31 - @clz(u32, phu_am_doi_match);
    } else {
        const phu_am_don_match = match & phu_am_don_mask;
        if (phu_am_don_match > 0) {
            pos = 31 - @clz(u32, phu_am_don_match);
        }
    }
    return initials[pos];
}

pub fn main() void {
    std.debug.print("{s}\n", .{getInitial('c', 'd')});
    std.debug.print("{s}\n", .{getInitial('x', 'e')});
    std.debug.print("{s}\n", .{getInitial('e', 'd')});
    std.debug.print("{s}\n", .{getInitial('z', 'd')});
}
