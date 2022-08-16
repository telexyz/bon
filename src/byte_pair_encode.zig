const std = @import("std");
const shc = @import("str_hash_count.zig");

const total_symbols = 3000;
const SymbolCount = shc.HashCount(total_symbols);

pub const BPE = struct {
    symbols: SymbolCount = undefined,
    len: usize = 0,
    vocabs: []u8 = undefined,

    const Self = @This();

    pub fn parse(self: *Self, vocabs: []u8) void {
        self.vocabs = vocabs;
    }
};
