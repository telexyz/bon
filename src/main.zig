const std = @import("std");
const v = @import("vector_types.zig");
const simd = @import("simd.zig");

pub fn main() void {
    // example values in set: {0x10, 0x21, 0xbd}
    //            not in set: {0x36, 0x91, 0xed}
    // input          = [36|10|91|21|10|ed|ed|21|36|bd|36|21|91|91|ed|10]
    //                      ^^    ^^ ^^       ^^    ^^    ^^          ^^
    const bitmap_0_07: v.u8x16 = simd.mm_setr_epi8(
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

    const input: v.u8x16 = simd.mm_setr_epi8(0x36, 0x10, 0x91, 0x21, 0x10, 0xed, 0xed, 0x21, 0x36, 0xbd, 0x36, 0x21, 0x91, 0x91, 0xed, 0x10);

    // lo_nibbles = [06|00|01|01|00|0d|0d|01|06|0d|06|01|01|01|0d|00]
    // hi_nibbles = [03|01|09|02|01|0e|0e|02|03|0b|03|02|09|09|0e|01]
    const lo_nibbles: v.u8x16 = simd.mm_and_si128(input, simd.mm_set1_epi8(0b0000_1111));
    const hi_nibbles: v.u8x16 = simd.mm_and_si128(simd.mm_srli_epi16(input, 4), simd.mm_set1_epi8(0b0000_1111));
    std.debug.print("\nlo_nibbles {x}\n", .{std.fmt.fmtSliceHexLower(&@as([16]u8, lo_nibbles))});
    std.debug.print("           06000101000d0d01060d060101010d00\n", .{});
    std.debug.print("\nhi_nibbles {x}\n", .{std.fmt.fmtSliceHexLower(&@as([16]u8, hi_nibbles))});
    std.debug.print("           03010902010e0e02030b030209090e01\n", .{});

    // row_0_07       = [a1|43|6f|6f|43|b8|b8|6f|a1|b8|a1|6f|6f|6f|b8|43]
    // row_8_15       = [14|24|b0|b0|24|0c|0c|b0|14|0c|14|b0|b0|b0|0c|24]
    const row_0_07: v.u8x16 = simd.mm_shuffle_epi8(bitmap_0_07, lo_nibbles);
    const row_8_15: v.u8x16 = simd.mm_shuffle_epi8(bitmap_8_15, lo_nibbles);

    std.debug.print("\nrow_0_07 {s}\n", .{std.fmt.fmtSliceHexLower(&@as([16]u8, row_0_07))});
    std.debug.print("         a1436f6f43b8b86fa1b8a16f6f6fb843\n", .{});
    std.debug.print("\nrow_8_15 {s}\n", .{std.fmt.fmtSliceHexLower(&@as([16]u8, row_8_15))});
    std.debug.print("         1424b0b0240c0cb0140c14b0b0b00c24\n", .{});

    const lookup: v.u8x16 = simd.mm_setr_epi8(1, 2, 4, 8, 16, 32, 64, 128, 1, 2, 4, 8, 16, 32, 64, 128);
    std.debug.print("\nlookup  {x}\n", .{std.fmt.fmtSliceHexLower(&@as([16]u8, lookup))});

    //                  0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
    // lookup       = [01|02|04|08|10|20|40|80|01|02|04|08|10|20|40|80]
    // hi_nibbles   = [03|01|09|02|01|0e|0e|02|03|0b|03|02|09|09|0e|01]
    // bitmask      = [08|02|02|04|02|40|40|04|08|08|08|04|02|02|40|02]
    //
    const bitmask: v.u8x16 = simd.mm_shuffle_epi8(lookup, hi_nibbles);
    std.debug.print("bitmask {s}\n", .{std.fmt.fmtSliceHexLower(&@as([16]u8, bitmask))});
    std.debug.print("        08020204024040040808080402024002\n", .{});

    const mask: v.u8x16 = simd.mm_cmplt_epi8(hi_nibbles, simd.mm_set1_epi8(8));
    std.debug.print("\nmask {s}\n", .{std.fmt.fmtSliceHexLower(&@as([16]u8, mask))});
    std.debug.print("     ffff00ffff0000ffff00ffff000000ff\n", .{});

    const bitset: v.u8x16 = simd.mm_blendv_epi8(row_8_15, row_0_07, mask);
    //          = [ff|ff|00|ff|ff|00|00|ff|ff|00|ff|ff|00|00|00|ff]
    // row_0_07 ? [a1|43|..|6f|43|..|..|6f|a1|..|a1|6f|..|..|..|43]
    // row_8_15 : [..|..|b0|..|..|0c|0c|..|..|0c|..|..|b0|b0|0c|..]
    std.debug.print("\nbitset {s}\n", .{std.fmt.fmtSliceHexLower(&@as([16]u8, bitset))});
    std.debug.print("       a143b06f430c0c6fa10ca16fb0b00c43\n", .{});

    // tmp            = [a1|43|b0|6f|43|0c|0c|6f|a1|0c|a1|6f|b0|b0|0c|43]
    //                & [08|02|02|04|02|40|40|04|08|08|08|04|02|02|40|02]
    //                = [00|02|00|04|02|00|00|04|00|08|00|04|00|00|00|02]
    //                      ^^    ^^ ^^       ^^    ^^    ^^          ^^
    const tmp: v.u8x16 = simd.mm_and_si128(bitset, bitmask);
    std.debug.print("\ntmp {s}\n", .{std.fmt.fmtSliceHexLower(&@as([16]u8, tmp))});
    std.debug.print("    00020004020000040008000400000002\n", .{});

    const result: v.u8x16 = simd.mm_cmpeq_epi8(tmp, bitmask);
    // input          = [36|10|91|21|10|ed|ed|21|36|bd|36|21|91|91|ed|10]
    //                      ^^    ^^ ^^       ^^    ^^    ^^          ^^
    std.debug.print("\nresult {d}\n", .{@as([16]u8, result)});
}
