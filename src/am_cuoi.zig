/// * Âm cuối:
/// - Các phụ âm cuối vần : p, t, c (ch), m, n, ng (nh)
/// - 2 bán âm cuối vần : i (y), u (o)
const std = @import("std");
const AmCuoi = @import("syllable.zig").AmCuoi;

const finals = [_]AmCuoi{
    AmCuoi.i,
    AmCuoi.u,
    AmCuoi.m,
    AmCuoi.n,
    AmCuoi.ng,
    AmCuoi.c,
    AmCuoi.p,
    AmCuoi.t,
    AmCuoi.ch,
    AmCuoi.nh,
    AmCuoi.y,
    AmCuoi.o,
    AmCuoi._none,
};

const u16x12 = std.meta.Vector(16, u16);
const lookup = u16x12{
    'i' << 8,
    'u' << 8,
    'm' << 8,
    'n' << 8,
    (@as(u16, 'n') << 8) + 'g',
    'c' << 8,
    'p' << 8,
    't' << 8,
    (@as(u16, 'c') << 8) + 'h',
    (@as(u16, 'n') << 8) + 'h',
    'y' << 8,
    'o' << 8,
};

pub inline fn getFinal(x: u8, y: u8) AmCuoi {
    const a = (@intCast(u16, x) << 8) + y;
    const input = u16x12{ a, a, a, a, a, a, a, a, a, a, a, a };
    const match: u12 = @ptrCast(*const u12, &(input == lookup)).*;
    const pos = if (match > 0) @ctz(u12, match) else 12;
    return finals[pos];
}

//
const u8x10 = std.meta.Vector(10, u16);
const lookup_ = u8x10{ 'm', 'n', 'c', 'p', 't', 'M', 'N', 'C', 'P', 'T' };

pub inline fn isFinalConsonant(x: u8) bool {
    const input = u8x10{ x, x, x, x, x, x, x, x, x, x };
    const match = @ptrCast(*const u10, &(input == lookup_)).*;
    return match > 0;
}

pub fn main() void {
    std.debug.print("\n{s}", .{@tagName(getFinal('i', 0))});
    std.debug.print("\n{s}", .{@tagName(getFinal('c', 'h'))});
    std.debug.print("\n{s}", .{@tagName(getFinal('c', 0))});

    std.debug.print("\n{}", .{isFinalConsonant('c')});
    std.debug.print("\n{}", .{isFinalConsonant('i')});
    std.debug.print("\n{}", .{isFinalConsonant('d')});
}
