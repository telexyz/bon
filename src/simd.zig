const std = @import("std");
const v = @import("vector_types.zig");

// Shuffle packed 8-bit integers in a according to shuffle control mask
// in the corresponding 8-bit element of b, and store the results in dst.
//
// Lệnh này tra cứu đồng thời 16-byte register (or lane)
// sử dụng 4-bit indices từ một vector khác:
//
// for (int i=0; i < VECTOR_SIZE; i++) {
//     uint8_t index = indices_vector[i];
//     if (index & 0x80) // 0x80: 0b10000000
//         result[i] = 0x00;
//     else
//         result[i] = lookup_vector[index & 0x0f]; // 0x0f = 0b1111
// }
//
// Trả về lookup_vector[n], với n = 4 bit thấp nhất của index
// Nếu bit thứ 8 của index = 1 thì kết quả luôn là 0 (clear flag)
// pshufb: Packed Shuffle Bytes (felixcloutier.com/x86/pshufb.html)
pub extern fn mm_shuffle_epi8(a: v.u8x16, b: v.u8x16) v.u8x16;
pub inline fn pshufb_m128(a: v.u8x16, b: v.u8x16) v.u8x16 {
    return mm_shuffle_epi8(a, b);
}

// Set packed 8-bit integers in dst with the supplied values in reverse order.
// dst[7:0] := v15, dst[15:8] := v14 .. dst[127:120] := v0
// dst = destination for shot
pub extern fn mm_setr_epi8(v15: u8, v14: u8, v13: u8, v12: u8, v11: u8, v10: u8, v9: u8, v8: u8, v7: u8, v6: u8, v5: u8, v4: u8, v3: u8, v2: u8, v1: u8, v0: u8) v.u8x16;
pub inline fn set8_rev_m128(v15: u8, v14: u8, v13: u8, v12: u8, v11: u8, v10: u8, v9: u8, v8: u8, v7: u8, v6: u8, v5: u8, v4: u8, v3: u8, v2: u8, v1: u8, v0: u8) v.u8x16 {
    return mm_setr_epi8(v15, v14, v13, v12, v11, v10, v9, v8, v7, v6, v5, v4, v3, v2, v1, v0);
}

// Shift packed 16-bit integers in a right by imm8 while shifting in zeros,
// and store the results in dst.
pub extern fn mm_srli_epi16(a: v.u8x16, b: u32) v.u8x16;
pub inline fn rshift16_m128(a: v.u8x16, b: u32) v.u8x16 {
    return mm_srli_epi16(a, b);
}

// Compare packed 8-bit integers in a and b for equality, and store the results in dst.
pub extern fn mm_cmpeq_epi8(a: v.u8x16, b: v.u8x16) v.u8x16;
pub inline fn cmpeq8_m128(a: v.u8x16, b: v.u8x16) v.u8x16 {
    return mm_cmpeq_epi8(a, b);
}

// Compare packed signed 8-bit integers in a and b for less-than, and store the results in dst.
// Note: This intrinsic emits the pcmpgtb instruction with the order of the operands switched.
pub extern fn mm_cmplt_epi8(a: v.u8x16, b: v.u8x16) v.u8x16;
pub inline fn cmplt8_m128(a: v.u8x16, b: v.u8x16) v.u8x16 {
    return mm_cmplt_epi8(a, b);
}

// Blend packed 8-bit integers from a and b using mask, and store the results in dst.
// FOR j := 0 to 15
//     i := j*8
//     IF mask[i+7]
//         dst[i+7:i] := b[i+7:i]
//     ELSE
//         dst[i+7:i] := a[i+7:i]
//     FI
// ENDFOR
pub extern fn mm_blendv_epi8(a: v.u8x16, b: v.u8x16, c: v.u8x16) v.u8x16;
pub inline fn blend8_m128(a: v.u8x16, b: v.u8x16, c: v.u8x16) v.u8x16 {
    return mm_blendv_epi8(a, b, c);
}

// Broadcast 8-bit integer a to all elements of dst. This intrinsic may generate vpbroadcastb.
pub extern fn mm_set1_epi8(x: u8) v.u8x16;
pub inline fn setall8_m128(x: u8) v.u8x16 {
    return mm_set1_epi8(x);
}

// Compute the bitwise AND of 128 bits (representing integer data) in a and b,
// and store the result in dst.
pub extern fn mm_and_si128(a: v.u8x16, b: v.u8x16) v.u8x16;
pub inline fn and_m128(a: v.u8x16, b: v.u8x16) v.u8x16 {
    return mm_and_si128(a, b);
}

pub extern fn mm_xor_si128(a: v.u8x16, b: v.u8x16) v.u8x16;
pub inline fn xor_m128(a: v.u8x16, b: v.u8x16) v.u8x16 {
    return mm_xor_si128(a, b);
}

pub extern fn mm_or_si128(a: v.u8x16, b: v.u8x16) v.u8x16;
pub inline fn or_m128(a: v.u8x16, b: v.u8x16) v.u8x16 {
    return mm_or_si128(a, b);
}
