const std = @import("std");
const AmDau = @import("syllable.zig").AmDau;

const initials: []const AmDau = &.{
    AmDau.x, //     0
    AmDau.v, //     1
    AmDau.s, //     2
    AmDau.r, //     3
    AmDau.m, //     4
    AmDau.l, //     5
    AmDau.h, //     6
    AmDau.d, //     7
    AmDau.b, //     8
    AmDau._none,
    AmDau.n, //    10
    AmDau.nh, //   11
    AmDau.g, //    12
    AmDau.gi, //   13
    AmDau._none,
    AmDau.q, //    15
    AmDau.t, //    16
    AmDau.tr, //   17
    AmDau.p, //    18
    AmDau.ph, //   19
    AmDau.c,
    AmDau.kh,
    AmDau.g,
    AmDau.gh,
    AmDau._none,
    AmDau.zd,
    AmDau.n, //
    AmDau.ng,
    AmDau.c,
    AmDau.ch,
    AmDau.t,
    AmDau.th,
    AmDau._none,
};

const u8x32 = std.meta.Vector(32, u8); // 8x32 = 32-bytes (vừa YMM registers)

// Để đặt vừa 25 phụ âm đầu (10 âm chiếm 2-bytes) trong một vector <= 32-bytes
// ta tận dụng sự trùng lặp của âm đầu 1-byte và byte đầu tiên âm đầu 2-bytes.
// Đó là 7 cặp âm: `t` và `th`, `c` và `ch`, `g` và `gh`, 'n' và `nh`,
// 'p' và 'ph', `t` và `th`, `g` và `gi`.
const lookup = u8x32{
    'x', 'v', 's', 'r', 'm', 'l', 'h', 'd', 'b', ' ', 'n', 'h', //
    'g', 'i', 'q', 'u', 't', 'r', 'p', 'h', 'k', 'h',
    'g', 'h', 196, 145, 'n', 'g', 'c', 'h', 't', 'h', // 'đ'196:145
};

// Để xác định đâu là phụ âm 1-byte ta cần dùng bitmask để lọc
const phu_am_don_mask = 0b01010101010101010001000111111111;

pub inline fn getInitial(f: u8, s: u8) AmDau {
    const input = u8x32{
        f, f, f, f, f, f, f, f, f, f, //
        f, s, f, s, f, s, f, s, f, s,
        f, s, f, s, f, s, f, s, f, s,
        f, s,
    };

    const match = @ptrCast(*const u32, &(input == lookup)).*; // Zig Vector `==` op
    // Mẹo thứ 2 là sau khi so sánh, ta dịch match bitmap sang phải 1 vị trí
    // và dùng phép & với match gốc, để xác định xem có 2 bit có giá trị là 1 liền kề nhau
    // không? Nếu có thì đó là phụ âm 2-bytes được tìm thấy
    const phu_am_doi_match = match << 1 & match;

    var pos: usize = 32;
    if (phu_am_doi_match > 0) {
        pos = 31 - @clz(phu_am_doi_match);

        // const c: []const u8 = &.{ f, s };
        // std.debug.print("\n\n'{s}'{x}:{x}", .{ c, f, s });
        // std.debug.print("\n{x:0>2}\n{x:0>2}", .{ input, lookup });
        // std.debug.print("\n{}", .{input == lookup});
        // std.debug.print("\n{b:0>32}, {d}\n", .{ phu_am_doi_match, pos });
    } else {
        // Nếu không tìm được phụ âm 2-bytes, ta dùng bitmask
        // để lọc ra phụ âm đơn 1-byte
        const phu_am_don_match = match & phu_am_don_mask;
        if (phu_am_don_match > 0) {
            pos = 31 - @clz(phu_am_don_match);
        }
    }

    return initials[pos];
}

pub fn main() void {
    std.debug.print("{s}\n", .{@tagName(getInitial('c', 'd'))});
    std.debug.print("{s}\n", .{@tagName(getInitial('x', 'e'))});
    std.debug.print("{s}\n", .{@tagName(getInitial('p', 'd'))});
    std.debug.print("{s}\n", .{@tagName(getInitial('e', 'd'))});
    std.debug.print("{s}\n", .{@tagName(getInitial('t', 'u'))});
    std.debug.print("{s}\n", .{@tagName(getInitial(196, 145))}); // 'đ'196:145
    std.debug.print("{s}\n", .{@tagName(getInitial('k', 'd'))});
    std.debug.print("{s}\n", .{@tagName(getInitial('q', 'u'))});
}

const expectEqual = std.testing.expectEqual;

// 22 phụ âm: b, c (k), ch, d, đ, g (gh), h, kh, l, m, n, nh, ng (ngh),
// p, ph, r, s, t, tr, th, v, x. (+ qu, gi, _none => 25)

test "getInitial(âm đơn thuần)" {
    const s = "bdhlmrsvx";
    const r = [_]AmDau{ .b, .d, .h, .l, .m, .r, .s, .v, .x };
    var i: usize = 0;
    while (i < s.len) : (i += 1) {
        const c = s[i];
        var b: u8 = 0;
        while (b < 128) : (b += 1) {
            try expectEqual(getInitial(c, b), r[i]);
        }
    }
}

// ch gh kh nh ng ph tr th gi
test "getInitial(âm đơn đứng đầu âm đôi)" {
    const s = "cgknpt";
    const r = [_]AmDau{ .c, .g, .c, .n, .p, .t };
    var i: usize = 0;
    while (i < s.len) : (i += 1) {
        const c = s[i];
        var b: u8 = 0;
        while (b < 128) : (b += 1) {
            if (b == 'h' and (c == 'n' or c == 'c' or c == 'g' or c == 'k' or c == 'p' or c == 't')) continue;
            if (b == 'g' and c == 'n') continue;
            if (b == 'r' and c == 't') continue;
            if (b == 'i' and c == 'g') continue;
            try expectEqual(getInitial(c, b), r[i]);
        }
    }
}

test "getInitial()" {
    try expectEqual(getInitial('b', 0), .b);
    try expectEqual(getInitial('c', 'd'), .c);
    try expectEqual(getInitial('k', 'd'), .c);
    try expectEqual(getInitial('c', 'h'), .ch);
    try expectEqual(getInitial('d', 'a'), .d);
    try expectEqual(getInitial(196, 145), .zd); // 'đ'196:145
    try expectEqual(getInitial('g', 0), .g);
    try expectEqual(getInitial('g', 'h'), .gh);
    try expectEqual(getInitial('g', 'i'), .gi);
    try expectEqual(getInitial('h', 0), .h);
    try expectEqual(getInitial('k', 'h'), .kh);
    try expectEqual(getInitial('l', 0), .l);
    try expectEqual(getInitial('m', 0), .m);
    try expectEqual(getInitial('n', 0), .n);
    try expectEqual(getInitial('n', 'h'), .nh);
    try expectEqual(getInitial('n', 'g'), .ng);
    try expectEqual(getInitial('p', 0), .p);
    try expectEqual(getInitial('p', 'h'), .ph);
    try expectEqual(getInitial('r', 0), .r);
    try expectEqual(getInitial('s', 0), .s);
    try expectEqual(getInitial('t', 0), .t);
    try expectEqual(getInitial('t', 'r'), .tr);
    try expectEqual(getInitial('t', 'h'), .th);
    try expectEqual(getInitial('v', 'u'), .v);
    try expectEqual(getInitial('x', 'i'), .x);
    try expectEqual(getInitial('q', 'i'), ._none);
    try expectEqual(getInitial('q', 'u'), .q);
}

test "getInitial(khe giữa 2 âm đôi)" {
    try expectEqual(getInitial('h', 't'), .h);
    try expectEqual(getInitial('g', 'c'), .g);
    try expectEqual(getInitial(145, 'n'), ._none);
    try expectEqual(getInitial('h', 196), .h);
    try expectEqual(getInitial('h', 'g'), .h);
    try expectEqual(getInitial('h', 'k'), .h);
    try expectEqual(getInitial('r', 'p'), .r);
    try expectEqual(getInitial('u', 't'), ._none);
    try expectEqual(getInitial('i', 'q'), ._none);
    try expectEqual(getInitial(' ', 'n'), ._none);
}
