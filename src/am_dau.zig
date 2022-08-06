// 22 phụ âm: b, c (k,q), ch, d, đ, g (gh), h, kh, l, m, n, nh, ng (ngh),
// p, ph, r, s, t, tr, th, v, x. (+ qu, gi, _none => 25)

const std = @import("std");
const AmDau = @import("syllable.zig").AmDau;

const initials: []const AmDau = &.{ AmDau.x, AmDau.v, AmDau.s, AmDau.r, AmDau.m, AmDau.l, AmDau._none, AmDau.h, AmDau.d, AmDau.b, AmDau._none, AmDau._none, AmDau.g, AmDau.gi, AmDau._none, AmDau.qu, AmDau._none, AmDau.tr, AmDau.p, AmDau.ph, AmDau.n, AmDau.ng, AmDau._none, AmDau.kh, AmDau.g, AmDau.gh, AmDau._none, AmDau.zd, AmDau.c, AmDau.ch, AmDau.t, AmDau.th, AmDau._none };

const u8x32 = std.meta.Vector(32, u8);

const lookup = u8x32{
    'x', 'v', 's', 'r', 'm', 'l', '-', 'h', 'd', 'b', '-', '-', //
    'g', 'i', 'q', 'u', 't', 'r', 'p', 'h', 'n', 'g', 'k', 'h',
    'g', 'h', 196, 145, 'c', 'h', 't', 'h', // 'đ'196:145
};

const phu_am_don_mask = 0b01010101010101010101001111111111;

pub inline fn getInitial(f: u8, s: u8) AmDau {
    const input = u8x32{
        f, f, f, f, f, f, f, f, f, f, f, f, //
        f, s, f, s, f, s, f, s, f, s, f, s,
        f, s, f, s, f, s, f, s,
    };

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
    std.debug.print("{s}\n", .{@tagName(getInitial('c', 'd'))});
    std.debug.print("{s}\n", .{@tagName(getInitial('x', 'e'))});
    std.debug.print("{s}\n", .{@tagName(getInitial('e', 'd'))});
    std.debug.print("{s}\n", .{@tagName(getInitial(196, 145))}); // 'đ'196:145
}
