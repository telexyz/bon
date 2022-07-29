const std = @import("std");
const v = @import("vector_types.zig");
const simd = @import("simd.zig");
const fmtHex = std.fmt.fmtSliceHexLower;

pub fn inSet(input_bytes: v.u8x16, bitmap_0_07: v.u8x16, bitmap_8_15: v.u8x16) v.u8x16 {
    const lookups: v.u8x16 =
        simd.set8_rev_m128(1, 2, 4, 8, 16, 32, 64, 128, 1, 2, 4, 8, 16, 32, 64, 128);

    const lo_nibbles: v.u8x16 = simd.and_m128(
        input_bytes,
        simd.setall8_m128(0b0000_1111),
    );
    const hi_nibbles: v.u8x16 = simd.and_m128(
        simd.rshift16_m128(input_bytes, 4), // right shift cùng lúc 2 input_bytes
        simd.setall8_m128(0b0000_1111),
    );

    // row_0_07       = [a1|43|6f|6f|43|b8|b8|6f|a1|b8|a1|6f|6f|6f|b8|43]
    // row_8_15       = [14|24|b0|b0|24|0c|0c|b0|14|0c|14|b0|b0|b0|0c|24]
    const row_0_07: v.u8x16 = simd.pshufb_m128(bitmap_0_07, lo_nibbles);
    const row_8_15: v.u8x16 = simd.pshufb_m128(bitmap_8_15, lo_nibbles);

    //                  0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
    // lookups      = [01|02|04|08|10|20|40|80|01|02|04|08|10|20|40|80]
    // hi_nibbles   = [03|01|09|02|01|0e|0e|02|03|0b|03|02|09|09|0e|01]
    // bitmasks     = [08|02|02|04|02|40|40|04|08|08|08|04|02|02|40|02]
    //
    // bitmasks[i] có bit tại vị trí hi_nibbles[i] là 1, còn lại là 0
    const bitmasks: v.u8x16 = simd.pshufb_m128(lookups, hi_nibbles);

    //
    // Cách tính bitsets[i] như sau:
    // Nếu hi_nibbles[i] mà <  8 thì chọn giá trị row_0_07[i]
    // Nếu hi_nibbles[i] mà >= 8 thì chọn giá trị row_8_15[i]
    const mask: v.u8x16 = simd.cmplt8_m128(hi_nibbles, simd.setall8_m128(8));
    const bitsets: v.u8x16 = simd.blend8_m128(row_8_15, row_0_07, mask);

    const results: v.u8x16 = simd.and_m128(bitsets, bitmasks);
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

    std.debug.print("\nnormalized_results {d}\n", .{@as([16]u8, inSet(
        input_bytes,
        bitmap_0_07,
        bitmap_8_15,
    ))});
}
