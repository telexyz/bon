// Triển khai thuật toán đã được chứng minh tại simd_byte_lookup.zig

const std = @import("std");
const v = @import("vector_types.zig");
const simd = @import("simd.zig");
const fmtHex = std.fmt.fmtSliceHexLower;

pub fn inSetBlend(input_bytes: v.u8x16, bitmap_0_07: v.u8x16, bitmap_8_15: v.u8x16) v.u8x16 {
    const lo_nibbles: v.u8x16 = simd.and_m128(
        input_bytes,
        simd.setall8_m128(0b0000_1111),
    );
    const hi_nibbles: v.u8x16 = simd.and_m128(
        simd.rshift16_m128(input_bytes, 4), // right shift cùng lúc 2 input_bytes
        simd.setall8_m128(0b0000_1111),
    );

    // bitmasks[0..3] có bit tại vị trí hi_nibbles[i] là 1, còn lại là 0
    // bitmasks[4..7] có bit tại vị trí hi_nibbles[i]-4 là 1, còn lại là 0
    const bitmasks: v.u8x16 = simd.pshufb_m128(
        simd.set8_rev_m128(1, 2, 4, 8, 16, 32, 64, 128, 1, 2, 4, 8, 16, 32, 64, 128),
        hi_nibbles,
    );

    const row_0_07: v.u8x16 = simd.pshufb_m128(bitmap_0_07, lo_nibbles);
    const row_8_15: v.u8x16 = simd.pshufb_m128(bitmap_8_15, lo_nibbles);

    // Nếu hi_nibbles[i] mà <  8 thì bitsets[i] = row_0_07[i]
    // Nếu hi_nibbles[i] mà >= 8 thì bitsets[i] = row_8_15[i]
    const mask: v.u8x16 = simd.cmplt8_m128(hi_nibbles, simd.setall8_m128(8));
    const bitsets: v.u8x16 = simd.blend8_m128(row_8_15, row_0_07, mask);

    const results: v.u8x16 = simd.and_m128(bitsets, bitmasks);
    return simd.cmpeq8_m128(results, bitmasks);
}

pub fn inSetNoBlend(input_bytes: v.u8x16, bitmap_0_07: v.u8x16, bitmap_8_15: v.u8x16) v.u8x16 {
    // http://0x80.pl/articles/simd-byte-lookup.html#alternative-implementation-new
    // https://github.com/intel/hyperscan/blob/master/src/nfa/truffle.c
    //
    const lo_nibbles = simd.and_m128(
        input_bytes,
        simd.setall8_m128(0b0000_1111),
    );
    const hi_nibbles = simd.and_m128(
        simd.rshift16_m128(input_bytes, 4), // right shift cùng lúc 2 input_bytes
        simd.setall8_m128(0b0000_1111),
    );
    const msblo_nibbles = simd.and_m128(
        input_bytes, // keep the most significant bits and lo_nibbles
        simd.setall8_m128(0b1000_1111),
    );

    // // bitmasks[0..3] có bit tại vị trí hi_nibbles[i] là 1, còn lại là 0
    // // bitmasks[4..7] có bit tại vị trí hi_nibbles[i]-4 là 1, còn lại là 0
    const bitmasks = simd.pshufb_m128(
        simd.set8_rev_m128(1, 2, 4, 8, 16, 32, 64, 128, 1, 2, 4, 8, 16, 32, 64, 128),
        hi_nibbles,
    );

    // nếu msb[i] = 1 thì row_0_07[i] = 0
    const row_0_07 = simd.pshufb_m128(bitmap_0_07, msblo_nibbles);
    //             = [a1|43|00|6f|43|00|00|6f|a1|00|a1|6f|00|00|00|43]

    const row_8_15 = simd.pshufb_m128(bitmap_8_15, lo_nibbles);
    //             = [14|24|b0|b0|24|0c|0c|b0|14|0c|14|b0|b0|b0|0c|24]

    // const msb = simd.and_m128(input_bytes, simd.setall8_m128(0b1000_0000));
    // std.debug.print("\nmsb      {s}\n", .{fmtHex(&@as([16]u8, msb))});
    // std.debug.print("row_0_07 {s}\n", .{fmtHex(&@as([16]u8, row_0_07))});
    // std.debug.print("         a143006f4300006fa100a16f00000043\n", .{});
    // std.debug.print("\nrow_8_15 {s}\n", .{fmtHex(&@as([16]u8, row_8_15))});
    // std.debug.print("         1424b0b0240c0cb0140c14b0b0b00c24\n", .{});

    const bitsets = simd.or_m128(row_0_07, row_8_15);
    // std.debug.print("\nbitsets {s}\n", .{fmtHex(&@as([16]u8, bitsets))});
    // std.debug.print("        b567b0ff670c0cffb50cb5ffb0b00c67\n", .{});

    const results = simd.and_m128(bitsets, bitmasks);
    return simd.cmpeq8_m128(results, bitmasks);
}

pub fn main() void {
    const bitmap_0_07: v.u8x16 = simd.set8_rev_m128(
        0b0100_0011,
        0b0110_1111,
        0b0101_0010,
        0b1000_0110,
        0b0000_0000,
        0b1101_0011,
        0b1010_0001,
        0b0000_0100,
        0b0000_1100,
        0b1001_1100,
        0b0100_0000,
        0b0100_1000,
        0b0001_0001,
        0b1011_1000,
        0b1000_0101,
        0b0100_0011,
    );

    const bitmap_8_15: v.u8x16 = simd.set8_rev_m128(
        0b0010_0100,
        0b1011_0000,
        0b0010_0100,
        0b0101_0100,
        0b1111_0000,
        0b1100_0101,
        0b0001_0100,
        0b0100_1000,
        0b1000_0000,
        0b0000_0100,
        0b1000_0100,
        0b0000_0000,
        0b1100_0000,
        0b0000_1100,
        0b0000_1010,
        0b0111_0000,
    );
    const input_bytes: v.u8x16 = simd.set8_rev_m128(0x36, 0x10, 0x91, 0x21, 0x10, 0xed, 0xed, 0x21, 0x36, 0xbd, 0x36, 0x21, 0x91, 0x91, 0xed, 0x10);

    std.debug.print("\ninSetBlend   {d}\n", .{@as([16]u8, inSetBlend(
        input_bytes,
        bitmap_0_07,
        bitmap_8_15,
    ))});

    std.debug.print("\ninSetNoBlend {d}\n", .{@as([16]u8, inSetNoBlend(
        input_bytes,
        bitmap_0_07,
        bitmap_8_15,
    ))});
}
