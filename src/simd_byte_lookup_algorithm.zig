//! Dịch từ http://0x80.pl/articles/simd-byte-lookup.html#simd-algorithms
//!
//! Cho 1 tập bytes, tìm byte-mask chỉ ra các bytes nào nằm trong một tập hợp cho trước.
//!
//!
//! ## Thuật toán chung
//!
//! Tập bytes cho trước được thể hiện ở dạng bảng `16 x 16` bits (hình dưới),
//! giá trị ô là 1 có nghĩa là thành phần đó của bảng có trong tập hợp.
//! Trong đó một byte được thể hiện bởi 2 nửa 4-bit được gọi là nibbles (miếng nhỏ).
//!
//! .     hi nibble
//!   .   +--------------------------------
//!     . | 0 1 2 3 4 5 6 7 8 9 a b c d e f
//!   +---+--------------------------------
//! l | 0 | x x . . . . x . . . x . . x . .
//! o | 1 | x x x x . x x . . . . . x x . x
//!   | 2 | . x . . x . x . . . x . . x . .
//! n | 3 | . x x . . . . x . . x . x . x .
//! i | 4 | . . . . . . . . . . . . x x x x
//! b | 5 | x x . . x . x x x . x . . . x x
//! b | 6 | x . . . . x . x . . x . x . . .
//! l | 7 | . . x . . . . . . . . x . . x .
//! e | 8 | . . x x . . . . . . . . . . . x
//!   | 9 | . . x x x . . x . . x . . . . .
//!   | a | . . . . . . x . . . x . . . . x
//!   | b | . . . x . . x . . . . . . . . .
//!   | c | x . . . x . . . . . . . . . x x
//!   | d | . . . x x x . x . . x x . . . .
//!   | e | x . x . . . . x . x . x . . . .
//!   | f | x x . . . . x . . . . . x x x .
//!
//! Thuật toán dưới dạng scalar code như sau:
//! bool in_set(uint16_t bitmap[16], uint8_t byte) {
//!
//!     const uint8_t lo_nibble = byte & 0b1111; // lấy 4-bit thâps
//!     const uint8_t hi_nibble = byte >> 4; // shift right để lấy 4-bit cao
//!
//!     const uint16_t bitset  = bitmap[lo_nibble]; // lấy giá trị của bitmap tại lo_nibble
//!     const uint16_t bitmask = uint16_t(1) << hi_nibble; // shift left hi_nibble pos
//!
//!     // bitmask có bit tại vị trí hi_nibble là 1, còn lại là 0. Dùng bitmap để xác định:
//!     // nếu bit tại vị trí hi_nibble của bitset là 1 thì trả về true
//!     return (bitset & bitmask) != 0;
//! }
//!
//! Để cài đặt bằng SIMD, ta bẻ bảng bit thành 2 nửa `bitmap_0_07` và `bitmap_8_15`
//! để đặt vừa 1 vector 128-bits. Rồi sử dụng lệnh `pshufb (_mm_shuffle_epi8)`,
//! có trong SSE, AVX2 và AVX-512. Lệnh này tra cứu đồng thời 16-byte register (or lane)
//! sử dụng 4-bit indices từ một vector khác:
//!
//! for (int i=0; i < VECTOR_SIZE; i++) {
//!     uint8_t index = indices_vector[i];
//!     if (index & 0x80) // 0x80: 0b10000000
//!         result[i] = 0x00;
//!     else
//!         result[i] = lookup_vector[index & 0x0f]; // 0x0f = 0b1111
//! }
//!
//! Trả về lookup_vector[n], với n = 4 bit thấp nhất của index
//! Nếu bit thứ 8 của index = 1 thì kết quả luôn là 0 (clear flag)
//!

const std = @import("std");
const v = @import("vector_types.zig");
const simd = @import("simd.zig");
const fmtHex = std.fmt.fmtSliceHexLower;

pub fn main() void {
    // example values in set: {0x10, 0x21, 0xbd}
    //            not in set: {0x36, 0x91, 0xed}
    // input_bytes    = [36|10|91|21|10|ed|ed|21|36|bd|36|21|91|91|ed|10]
    //                      ^^    ^^ ^^       ^^    ^^    ^^          ^^
    //
    const lookups: v.u8x16 = simd.setrev8_m128(1, 2, 4, 8, 16, 32, 64, 128, 1, 2, 4, 8, 16, 32, 64, 128);

    const input_bytes: v.u8x16 = simd.setrev8_m128(0x36, 0x10, 0x91, 0x21, 0x10, 0xed, 0xed, 0x21, 0x36, 0xbd, 0x36, 0x21, 0x91, 0x91, 0xed, 0x10);

    const bitmap_0_07: v.u8x16 = simd.setrev8_m128(
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

    const bitmap_8_15: v.u8x16 = simd.setrev8_m128(
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

    // lo_nibbles = [06|00|01|01|00|0d|0d|01|06|0d|06|01|01|01|0d|00]
    // hi_nibbles = [03|01|09|02|01|0e|0e|02|03|0b|03|02|09|09|0e|01]
    const lo_nibbles: v.u8x16 = simd.and_m128(
        input_bytes,
        simd.setall8_m128(0b0000_1111),
    );
    const hi_nibbles: v.u8x16 = simd.and_m128(
        simd.rshift16_m128(input_bytes, 4), // right shift 4 pos for 16-bits
        // tức là right shift cùng lúc 2 input_bytes
        simd.setall8_m128(0b0000_1111),
    );
    std.debug.print("\nlo_nibbles {x}\n", .{fmtHex(&@as([16]u8, lo_nibbles))});
    std.debug.print("           06000101000d0d01060d060101010d00\n", .{});
    std.debug.print("\nhi_nibbles {x}\n", .{fmtHex(&@as([16]u8, hi_nibbles))});
    std.debug.print("           03010902010e0e02030b030209090e01\n", .{});

    // row_0_07       = [a1|43|6f|6f|43|b8|b8|6f|a1|b8|a1|6f|6f|6f|b8|43]
    // row_8_15       = [14|24|b0|b0|24|0c|0c|b0|14|0c|14|b0|b0|b0|0c|24]
    const row_0_07: v.u8x16 = simd.pshufb_m128(bitmap_0_07, lo_nibbles);
    const row_8_15: v.u8x16 = simd.pshufb_m128(bitmap_8_15, lo_nibbles);
    //
    std.debug.print("\nrow_0_07 {s}\n", .{fmtHex(&@as([16]u8, row_0_07))});
    std.debug.print("         a1436f6f43b8b86fa1b8a16f6f6fb843\n", .{});
    std.debug.print("\nrow_8_15 {s}\n", .{fmtHex(&@as([16]u8, row_8_15))});
    std.debug.print("         1424b0b0240c0cb0140c14b0b0b00c24\n", .{});

    //                  0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
    // lookups      = [01|02|04|08|10|20|40|80|01|02|04|08|10|20|40|80]
    // hi_nibbles   = [03|01|09|02|01|0e|0e|02|03|0b|03|02|09|09|0e|01]
    // bitmasks     = [08|02|02|04|02|40|40|04|08|08|08|04|02|02|40|02]
    //
    // bitmasks[0..3] có bit tại vị trí hi_nibbles[i] là 1, còn lại là 0
    // bitmasks[4..7] có bit tại vị trí hi_nibbles[i]-4 là 1, còn lại là 0
    const bitmasks: v.u8x16 = simd.pshufb_m128(lookups, hi_nibbles);
    std.debug.print("bitmasks {s}\n", .{fmtHex(&@as([16]u8, bitmasks))});
    std.debug.print("        08020204024040040808080402024002\n", .{});

    // Nếu hi_nibbles[i] mà <  8 thì bitsets[i] = row_0_07[i]
    // Nếu hi_nibbles[i] mà >= 8 thì bitsets[i] = row_8_15[i]
    const mask: v.u8x16 = simd.cmplt8_m128(hi_nibbles, simd.setall8_m128(8));
    std.debug.print("\nmask {s}\n", .{fmtHex(&@as([16]u8, mask))});
    std.debug.print("     ffff00ffff0000ffff00ffff000000ff\n", .{});

    const bitsets: v.u8x16 = simd.blend8_m128(row_8_15, row_0_07, mask);
    //          = [ff|ff|00|ff|ff|00|00|ff|ff|00|ff|ff|00|00|00|ff]
    // row_0_07 ? [a1|43|..|6f|43|..|..|6f|a1|..|a1|6f|..|..|..|43]
    // row_8_15 : [..|..|b0|..|..|0c|0c|..|..|0c|..|..|b0|b0|0c|..]
    std.debug.print("\nbitsets {s}\n", .{fmtHex(&@as([16]u8, bitsets))});
    std.debug.print("        a143b06f430c0c6fa10ca16fb0b00c43\n", .{});

    //
    // results        = [a1|43|b0|6f|43|0c|0c|6f|a1|0c|a1|6f|b0|b0|0c|43]
    //                & [08|02|02|04|02|40|40|04|08|08|08|04|02|02|40|02]
    //                = [00|02|00|04|02|00|00|04|00|08|00|04|00|00|00|02]
    //                      ^^    ^^ ^^       ^^    ^^    ^^          ^^
    const results: v.u8x16 = simd.and_m128(bitsets, bitmasks);
    std.debug.print("\nresults {s}\n", .{fmtHex(&@as([16]u8, results))});
    std.debug.print("        00020004020000040008000400000002\n", .{});

    const normalized_results: v.u8x16 = simd.cmpeq8_m128(results, bitmasks);
    // input          = [36|10|91|21|10|ed|ed|21|36|bd|36|21|91|91|ed|10]
    //                      ^^    ^^ ^^       ^^    ^^    ^^          ^^
    std.debug.print("\nnormalized_results {d}\n", .{@as([16]u8, normalized_results)});
}
