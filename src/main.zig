const std = @import("std");
const v = @import("vector_types.zig");
const simd = @import("simd.zig");

pub fn main() void {
    // example values in set: {0x10, 0x21, 0xbd}
    //            not in set: {0x36, 0x91, 0xed}
    // input          = [36|10|91|21|10|ed|ed|21|36|bd|36|21|91|91|ed|10]
    //                      ^^    ^^ ^^       ^^    ^^    ^^          ^^
    // lower_nibbles  = [06|00|01|01|00|0d|0d|01|06|0d|06|01|01|01|0d|00]
    // higher_nibbles = [03|01|09|02|01|0e|0e|02|03|0b|03|02|09|09|0e|01]

    const input: v.u8x16 = simd.mm_setr_epi8(0x36, 0x10, 0x91, 0x21, 0x10, 0xed, 0xed, 0x21, 0x36, 0xbd, 0x36, 0x21, 0x91, 0x91, 0xed, 0x10);
    std.debug.print("\ninput {b}\n", .{@as([16]u8, input)});

    const bitmap_0_7: v.u8x16 = simd.mm_setr_epi8(
        0x43, // 01000011
        0x6f, // 01101111
        0x52, // 01010010
        0x86, // 10000110
        0x00, // 00000000
        0xd3, // 11010011
        0xa1, // 10100001
        0x04, // 00000100
        0x0c, // 00001100
        0x9c, // 10011100
        0x40, // 01000000
        0x48, // 01001000
        0x11, // 00010001
        0xb8, // 10111000
        0x85, // 10000101
        0x43, // 01000011
    );
    std.debug.print("\nbitmap_0_7 {b}\n", .{@as([16]u8, bitmap_0_7)});

    const bitmap_8_15: v.u8x16 = simd.mm_setr_epi8(
        0x24, // 00100100
        0xb0, // 10110000
        0x24, // 00100100
        0x54, // 01010100
        0xf0, // 11110000
        0xc5, // 11000101
        0x14, // 00010100
        0x48, // 01001000
        0x80, // 10000000
        0x04, // 00000100
        0x84, // 10000100
        0x00, // 00000000
        0xc0, // 11000000
        0x0c, // 00001100
        0x0a, // 00001010
        0x70, // 01110000
    );
    std.debug.print("\nbitmap_8_15 {b}\n", .{@as([16]u8, bitmap_8_15)});

    const bitmask_lookup: v.u8x16 = simd.mm_setr_epi8(1, 2, 4, 8, 16, 32, 64, 128, 1, 2, 4, 8, 16, 32, 64, 128);
    std.debug.print("\nbitmask_lookup {b}\n", .{@as([16]u8, bitmask_lookup)});
}
