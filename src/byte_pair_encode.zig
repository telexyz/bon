const std = @import("std");
const shc = @import("str_hash_count.zig");

const total_symbols = 3000;
const SymbolCount = shc.HashCount(total_symbols);

pub const BPE = struct {
    allocator: std.mem.Allocator,
    // dữ liệu cần tìm ra
    symbols: SymbolCount = undefined,
    len: usize = 0,

    // dữ liệu đầu vào và phụ trợ
    vocabs: []const u8 = undefined,
    symbol_lens: []u8 = undefined,
    total_vocabs: usize = undefined,

    const Self = @This();

    pub fn learn(self: *Self) void {
        _ = self;
        // 1/ chọn 2 symbols liền kề có count lớn nhất trong vocabs
        // 2/ thay thế trong vocabs 2 symbols liền kề được chọn bởi 1 symbol mới
        // 3/ lặp lại bước 1/ `k` lần

        // 1/ Dùng `symbols: SymbolCount` để tính count cho cặp symbol tiềm năng

        // Heuristic để dừng việc scan vocabs
        // Giả sử đang scan tới hết key thứ `i` ở vị trí `x` trong vocabs
        // và biết `c` là count của next key:
        // remain_keys = total_vocabs - i;
        // guest_avg_count = (c / remain_keys) + 1
        // remain_bytes = vocabs.len - x - remain_keys * 3
        // guest_max_count = (remain_bytes / symbol.len) * guest_avg_count
        // Nếu candidate_1st_count > candidate_2nd_count + guest_max_count thì dừng việc scan vocabs

    }

    pub fn showCandidates(self: *Self) void {
        var candi_1st = shc.Entry{ .count = 0 };
        var candi_2nd: shc.Entry = undefined;
        const entries = self.symbols.slice();
        for (entries) |entry| {
            if (entry.count > candi_1st.count) {
                candi_2nd = candi_1st;
                candi_1st = entry;
            }
        }
        std.debug.print("\n\ncandi_1st: `{s}` {d}\ncandi_2nd: `{s}` {d}\n\n", .{ self.symbols.key_str(candi_1st.offset), candi_1st.count, self.symbols.key_str(candi_2nd.offset), candi_2nd.count });
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.symbol_lens);
        self.symbols.deinit();
    }
    pub fn init(self: *Self, init_allocator: std.mem.Allocator, vocabs: []const u8) !void {
        self.vocabs = vocabs;
        self.allocator = init_allocator;
        self.symbol_lens = try self.allocator.alloc(u8, vocabs.len);
        try self.symbols.init(self.allocator);

        var x: usize = 0;
        self.total_vocabs = 0;

        while (x < vocabs.len) {
            x += 2; // bỏ qua 2-bytes lưu count
            var ending = x + vocabs[x] + 1;
            x += 1; // trỏ tới đầu key
            self.total_vocabs += 1;

            // std.debug.print("\n{d} `{s}` ", .{ ending - x, vocabs[x..ending] });

            while (x < ending) {
                // Algo from `zig/std/unicode.zig`
                // The switch is optimized much better than a "smart" approach using @clz
                switch (vocabs[x]) {
                    0b0000_0000...0b0111_1111 => self.symbol_lens[x] = 1,
                    0b1100_0000...0b1101_1111 => self.symbol_lens[x] = 2,
                    0b1110_0000...0b1110_1111 => self.symbol_lens[x] = 3,
                    0b1111_0000...0b1111_0111 => self.symbol_lens[x] = 4,
                    else => { // error.Utf8InvalidStartByte
                        // treat phần còn lại của key là chuỗi byte
                        std.mem.set(u8, self.symbol_lens[x..ending], 1);
                        x = ending;
                        break;
                    },
                }
                const next = x + self.symbol_lens[x];
                if (next > ending) {
                    // Lỗi ko đủ byte cho symbol
                    // treat phần còn lại của key là chuỗi byte
                    std.mem.set(u8, self.symbol_lens[x..ending], 1);
                    x = ending;
                    break;
                }
                const symbol = vocabs[x..next];
                self.symbols.put(symbol);
                // std.debug.print("{s}:{d} ", .{ symbol, symbol.len });
                x = next;
            } // key
        } // vocabs
    }
};
