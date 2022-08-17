const std = @import("std");
const shc = @import("str_hash_count.zig");

const max_total_chars = 100_000;
const max_total_symbols = 3_000;
const SymbolCount = shc.HashCount(max_total_chars + max_total_symbols);
const CharCount = shc.HashCount(max_total_chars); // Unicode: 144,697 characters

pub const BPE = struct {
    allocator: std.mem.Allocator,
    // dữ liệu cần tìm ra
    selected_symbols: []shc.Entry = undefined,
    total_selected: usize = 0,

    // dữ liệu đầu vào và phụ trợ
    vocabs: []const u8 = undefined,
    symbols_len: []u8 = undefined,
    total_vocabs: usize = undefined,
    symbols_count: SymbolCount = undefined,
    chars_count: CharCount = undefined,

    const Self = @This();

    pub fn learn(self: *Self) void {
        // 0/ Khởi tạo tập selected là các chars (done)
        // 1/ chọn 2 symbols liền kề có count lớn nhất trong vocabs để bổ xung vào tập selected
        // 2/ thay thế trong vocabs 2 symbols liền kề được chọn bởi 1 symbol mới
        // 3/ lặp lại bước 1/ `k` lần

        const vocabs = self.vocabs;

        while (self.total_selected < max_total_symbols) {
            //
            std.debug.print("\n>> Finding new candidates <<\n", .{});
            var candi_1st = shc.Entry{ .count = 0 };
            var candi_2nd = candi_1st;

            self.symbols_count.reset();
            var i: usize = 0;

            while (i < vocabs.len) {
                const count = vocabs[i] * @as(u32, 256) + vocabs[i + 1];
                i += 3;
                const key_end = i + vocabs[i - 1]; // i + key_len
                // Tìm các cặp symbols liền nhau trong key
                var curr_symbol = i;
                i += self.symbols_len[i]; // curr_symbol_end
                while (i < key_end) {
                    const next_symbol_end = i + self.symbols_len[i];
                    const pair = vocabs[curr_symbol..next_symbol_end];
                    const entry = self.symbols_count.put_count(pair, count).?; // optional pointer
                    if (entry.count > candi_1st.count) {
                        if (candi_1st.offset != entry.offset) {
                            candi_2nd = candi_1st;
                        }
                        candi_1st = entry.*;
                    } else if (entry.count > candi_2nd.count and candi_1st.offset != entry.offset) {
                        candi_2nd = entry.*;
                    }
                    curr_symbol = i;
                    i = next_symbol_end;
                }
            }
            if (candi_1st.count == 0) break;
            if (candi_2nd.count == 0) candi_2nd = candi_1st;

            std.debug.print("\n\ncandi_1st: `{s}` {d}\ncandi_2nd: `{s}` {d}\n\n", .{
                self.symbols_count.key_str(candi_1st.offset),
                candi_1st.count,
                self.symbols_count.key_str(candi_2nd.offset),
                candi_2nd.count,
            });

            self.selected_symbols[self.total_selected] = candi_1st;
            self.mark(candi_1st);
            self.total_selected += 1;
        }

        // Heuristic để dừng việc scan vocabs
        // Giả sử đang scan tới hết key thứ `i` ở vị trí `x` trong vocabs
        // và biết `c` là count của next key:
        // remain_keys = total_vocabs - i;
        // guest_avg_count = (c / remain_keys) + 1
        // remain_bytes = vocabs.len - x - remain_keys * 3
        // guest_max_count = (remain_bytes / symbol.len) * guest_avg_count
        // Nếu candidate_1st_count > candidate_2nd_count + guest_max_count thì dừng việc scan vocabs
    }

    fn mark(self: *Self, entry: shc.Entry) void {
        const key = self.symbols_count.key_str(entry.offset);
        std.debug.print("\n>> Marking `{s}` {} <<\n", .{ key, entry });
        const vocabs = self.vocabs;
        const syms_len = self.symbols_len;
        var i: usize = 3;
        var token_end = i + vocabs[i - 1];
        while (i < vocabs.len) {
            const sym_end = i + key.len;
            if (sym_end <= token_end and std.mem.eql(u8, key, vocabs[i..sym_end])) {
                syms_len[i] = @intCast(u8, key.len);
            }
            i += syms_len[i];
            if (i == token_end) {
                i += 3;
                if (i < vocabs.len) {
                    token_end = i + vocabs[i - 1];
                }
            }
        }
        std.debug.print("\n>> Marking `{s}` done! <<\n", .{key});
    }

    pub fn showSelected(self: *Self, n: usize) void {
        std.debug.print("\n\n(( BPE selected symbols ))\n\n", .{});
        for (self.selected_symbols[0..self.total_selected]) |entry, i| {
            if (i == n) break;
            const key = self.symbols_count.key_str(entry.offset);
            std.debug.print("'{s}':{d} \t", .{ key, entry.count });
        }

        std.debug.print("\n\nTOTAL: {d} symbols\n", .{self.symbols_count.len});
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.symbols_len);
        self.allocator.free(self.selected_symbols);
        self.symbols_count.deinit();
        self.chars_count.deinit();
    }
    pub fn init(self: *Self, init_allocator: std.mem.Allocator, vocabs: []const u8) !void {
        self.vocabs = vocabs;
        self.allocator = init_allocator;
        self.symbols_len = try self.allocator.alloc(u8, vocabs.len);
        std.mem.set(u8, self.symbols_len[0..], 0);
        try self.symbols_count.init(self.allocator);
        try self.chars_count.init(self.allocator);
        self.total_selected = 0;
        self.selected_symbols = try self.allocator.alloc(shc.Entry, max_total_symbols);

        var x: usize = 0;
        self.total_vocabs = 0;

        while (x < vocabs.len) {
            const key_count = vocabs[x] * @as(u16, 256) + vocabs[x + 1];
            x += 2; // bỏ qua 2-bytes lưu count
            var ending = x + vocabs[x] + 1;
            x += 1; // trỏ tới đầu key
            self.total_vocabs += 1;

            // std.debug.print("\n{d} `{s}` ", .{ ending - x, vocabs[x..ending] });

            while (x < ending) {
                // Algo from `zig/std/unicode.zig`
                // The switch is optimized much better than a "smart" approach using @clz
                switch (vocabs[x]) {
                    0b0000_0000...0b0111_1111 => self.symbols_len[x] = 1,
                    0b1100_0000...0b1101_1111 => self.symbols_len[x] = 2,
                    0b1110_0000...0b1110_1111 => self.symbols_len[x] = 3,
                    0b1111_0000...0b1111_0111 => self.symbols_len[x] = 4,
                    else => { // error.Utf8InvalidStartByte
                        // treat phần còn lại của key là chuỗi byte
                        std.mem.set(u8, self.symbols_len[x..ending], 1);
                        x = ending;
                        break;
                    },
                }
                const next = x + self.symbols_len[x];
                if (next > ending) {
                    // Lỗi ko đủ byte cho symbol
                    // treat phần còn lại của key là chuỗi byte
                    std.mem.set(u8, self.symbols_len[x..ending], 1);
                    x = ending;
                    break;
                }
                const symbol = vocabs[x..next];
                _ = self.chars_count.put_count(symbol, key_count);
                // std.debug.print("{s}:{d}:{d} ", .{ symbol, symbol.len, entry.count });
                x = next;
            } // key: x < ending
        } // vocabs
    }
};
