const std = @import("std");
const ahc = @import("alcon_hash_count.zig");

const Pair = struct {
    id: u16,
    // id: 0 .. 255 => byte
    // id > 255 => look for value at value_offset
    value_offset: u16,
    count: u32,
};
