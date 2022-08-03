//! 22 phụ âm: b, c (k,q), ch, d, đ, g (gh), h, kh, l, m, n, nh, ng (ngh),
//! p, ph, r, s, t, tr, th, v, x. (+ qu, gi, _none => 25)
//!
//! am_tiet: "nghóng";
//!
//! 1/ Tìm phụ âm đầu
//! phu_am_don: u8x16 = "bckqdghlmnprstvx"; // 16-byte
//! phu_am_doi: u16x16 = "chzdghkhngphtrthqugi"; // 20-byte
//
//! 1.a/
//! v: u8x32 = (am_tiet[0] + am_tiet[1]) ** 10;

const std = @import("std");
const v = @import("vector_types.zig");
const simd = @import("simd.zig");

inline fn initAmDauVec(c1: u8, c2: u8) v.u8x32 {
    const a = (@intCast(u16, c2) << 8) + c1;
    const b = (@intCast(u16, c1) << 8) + c1;
    // return simd.set16_m256(a, a, a, a, a, a, a, a, a, a, b, b, b, b, b, b);
    const e = (@intCast(u32, a) << 16) + a;
    const f = (@intCast(u32, b) << 16) + b;
    return simd.mm256_set_epi32(e, e, e, e, e, f, f, f);
}

pub fn main() void {
    const lookup = simd.set8_m256('h', 't', 'h', 'c', 'd', 'z', 'h', 'g', 'h', 'k', 'g', 'n', 'h', 'p', 'r', 't', 'u', 'q', 'i', 'g', '-', '-', 'b', 'd', 'h', '-', 'l', 'm', 'r', 's', 'v', 'x');

    // const input = initAmDauVec('c', 'd');
    // const input = initAmDauVec('x', 'e');
    // const input = initAmDauVec('e', 'e');
    const input = initAmDauVec('z', 'd');
    std.debug.print("\ninput  {c}\nlookup {c}\n", .{ input, lookup });

    const match: u32 = simd.movemask8_m256(simd.cmpeq8_m256(input, lookup));
    // const match: u32 = @ptrCast(*const u32, &(input == lookup)).*; // Zig Vector `==` op
    std.debug.print("\nmatch {b}\n", .{match});

    const phu_am_doi_match = match << 1 & match;

    var pos: u32 = 32;
    if (phu_am_doi_match > 0) {
        pos = 31 - @clz(u32, phu_am_doi_match);
        if (pos % 2 == 0) {
            std.debug.print("\nPhụ âm đơn trong âm đôi pos = {d}, match = {b}\n", .{ pos, phu_am_doi_match });
        } else {
            std.debug.print("\nPhụ âm đôi pos = {d}, match = {b}\n", .{ pos, phu_am_doi_match });
        }
    } else {
        const phu_am_don_mask = 0b01010101010101010101001111111111;
        const phu_am_don_match = match & phu_am_don_mask;
        if (phu_am_don_match > 0) {
            pos = 31 - @clz(u32, phu_am_don_match);
            std.debug.print("\nPhụ âm đơn độc lập pos = {d}, match = {b}\n", .{ pos, phu_am_don_match });
        } else {
            std.debug.print("\nKhông có phụ âm đầu {d}, {b}\n", .{ pos, phu_am_don_match });
        }
    }

    const initials: []const []const u8 = &.{ "x", "v", "s", "r", "m", "l", "6", "h", "d", "b", "10", "11", "g", "gi", "q", "qu", "18", "tr", "p", "ph", "n", "ng", "k", "kh", "g", "gh", "0", "zd", "c", "ch", "t", "th", "0" };
    std.debug.print("\nPhụ âm đầu = `{s}`\n", .{initials[pos]});
}
// http://0x80.pl/notesen/2019-02-03-simd-switch-implementation.html

// const value = @Vector(4, i32){ 1, -1, 1, -1 };
// const result = value > @splat(4, @as(i32, 0));
// // result is { true, false, true, false };
// comptime try expect(@TypeOf(result) == @Vector(4, bool));
// const is_all_true = @reduce(.And, result);
// comptime try expect(@TypeOf(is_all_true) == bool);
// try expect(is_all_true == false);
