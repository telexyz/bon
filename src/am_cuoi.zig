/// * Âm cuối:
/// - Các phụ âm cuối vần : p, t, c (ch), m, n, ng (nh)
/// - 2 bán âm cuối vần : i (y), u (o)
const std = @import("std");
const v = @import("vector_types.zig");
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

const lookup = v.u16x16{
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
    0,
    0,
    0,
    0,
};

pub inline fn getFinal(x: u8, y: u8) AmCuoi {
    const a = (@intCast(u16, x) << 8) + y;
    const input = v.u16x16{ a, a, a, a, a, a, a, a, a, a, a, a, a, a, a, a };
    const match16: u16 = @ptrCast(*const u16, &(input == lookup)).*;
    const pos16 = if (match16 > 0) @ctz(u16, match16) else 12;
    return finals[pos16];
}

//
const lookup_ = std.meta.Vector(10, u8){ 'm', 'n', 'c', 'p', 't', 'M', 'N', 'C', 'P', 'T' };

pub inline fn isFinalConsonant(x: u8) bool {
    const input = std.meta.Vector(10, u8){ x, x, x, x, x, x, x, x, x, x };
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
