// Coi tokens là tập hợp bytes (đơn vị nhỏ nhất có thể)
// Có thể giả sử encode dài nhất <= 32-bytes
// Đầu tiên cần tính count của mọi utf-8 chars trong alco_hash_count
// của các token ko phải âm tiết tiếng Việt.

const std = @import("std");
const ahc = @import("alcon_hash_count.zig");

const Pair = struct {
    id: u16,
    // id: 0 .. 255 => byte
    // id > 255 => look for value at value_offset
    value_offset: u16,
    count: u32,
};

// Đầu vào các tokens đã được count sẵn trong `counters: ahc.HashCount1M` từ `char_stream.zig`
// counters chứa `keys_bytes` và `keys_bytes_len` là 1 chuỗi các `types` (uniq tokens)
// Để xác định count của `pair` ta search pair's value trong keys_bytes,
// để xác định keys có chứa pair's value, cộng dồn counts của các keys đó được count của pair
//
// => Cần 1 bước đệm là map key's ending vào key's count (u24)
// => Để dành 3-bytes sau key's ending để lưu key's count
//
// * `key_string`\0x010203\0x20
// * 0x20 GUARD_BYTE
// * 0x010203 `key_count` (3-bytes)
