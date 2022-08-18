const std = @import("std");
const shc = @import("str_hash_count.zig");

const max_total_chars = 100_000;
const max_selected_symbols = 300;
const max_total_symbols = 1_000_000;
const SymbolCount = shc.HashCount(max_total_symbols);
const CharCount = shc.HashCount(max_total_chars); // Unicode: 144,697 characters

pub const BPE = struct {
    allocator: std.mem.Allocator,
    // dữ liệu cần tìm ra
    selected_symbols: []shc.Entry = undefined,
    total_selected: usize = 0,

    // dữ liệu đầu vào và phụ trợ
    vocabs: []const u8 = undefined,
    symbols_len: []u8 = undefined,
    total_keys: usize = undefined,
    pairs_count: SymbolCount = undefined,
    chars_count: CharCount = undefined,
    candidates: []usize = undefined,
    total_candidates: usize = 0,

    const Self = @This();

    pub fn learn(self: *Self) void {
        // 1/ chọn 2 symbols liền kề có count lớn nhất trong vocabs để bổ xung vào tập selected
        // 2/ thay thế trong vocabs 2 symbols liền kề được chọn bởi 1 symbol mới
        // 3/ lặp lại bước 1/ `k` lần

        const vocabs = self.vocabs;
        var i: usize = 0;

        self.total_candidates = 0;
        while (i < vocabs.len) {
            const count = vocabs[i] * @as(u32, 256) + vocabs[i + 1];
            i += 3; // trỏ tới key's begin
            const key_len = vocabs[i - 1];
            const key_end = i + key_len;
            // key = vocabs[i..key_end]
            // Tìm các cặp symbols liền nhau trong key
            var curr_symbol = i;
            i += self.symbols_len[i]; // curr_symbol_end
            while (i < key_end) {
                const next_symbol_end = i + self.symbols_len[i];
                const pair = vocabs[curr_symbol..next_symbol_end];
                // const k = self.total_selected; // lần lựa chọn thứ k
                const idx = self.pairs_count.put_count(pair, count); // optional pointer
                if (self.pairs_count.entries[idx].count == count) { // new entry
                    self.candidates[self.total_candidates] = idx;
                    self.total_candidates += 1;
                }
                curr_symbol = i;
                i = next_symbol_end;
            }
        }

        var candi: shc.Entry = undefined;
        var candi_idx: usize = undefined;

        while (self.total_selected < max_selected_symbols) {
            // find next candi
            // std.debug.print("\n>> Finding new candidates <<\n", .{});
            candi.count = 0;
            for (self.candidates[0..self.total_candidates]) |entry_idx, idx| {
                const entry = self.pairs_count.entries[entry_idx];
                if (entry.count > candi.count) {
                    // std.debug.print("{d}`{s}`{d} \t", .{ idx, self.pairs_count.key_str(entry.offset), entry.count });
                    candi = entry;
                    candi_idx = idx;
                }
            }

            if (candi.count == 0) return; // no more candi

            // Loại selected candi from `candidates`
            self.total_candidates -= 1;
            self.candidates[candi_idx] = self.candidates[self.total_candidates];
            // std.debug.print("\n\ncandidate[{d}]:`{s}`-{d} ", .{ candi_idx, self.pairs_count.key_str(candi.offset), candi.count });
            self.selected_symbols[self.total_selected] = candi;
            self.mark(candi);
            self.total_selected += 1;
        } // self.total_selected < max_selected_symbols

    }

    // TODO: BPE hiện đang bị nghẽn ở mark()
    // => Tìm cách cải thiện tốc độ substr matching
    // * Dùng nhiều threads (chia để trị)
    // * Dùng SIMD để match cùng lúc nhiều bytes (64 bytes 1 lần so sánh)
    fn mark(self: *Self, entry: shc.Entry) void {
        const vocabs = self.vocabs;
        const syms_len = self.symbols_len;
        const pair = self.pairs_count.key_str(entry.offset);

        var i: usize = 3;
        var key_count = vocabs[0] * @as(u32, 256) + vocabs[1];
        var key_begin = i;
        var key_end = i + vocabs[2];
        const dont_exist = 0;
        var prev_sym: usize = dont_exist;

        const show_info = false; //std.mem.eql(u8, pair, "chi");
        if (show_info) std.debug.print("\nMarking `{s}`: ", .{pair});

        while (i < vocabs.len) { // quét toàn bộ vocabs
            const sym_end = i + syms_len[i];
            if (sym_end < key_end) {
                //
                const next_sym_end = sym_end + syms_len[sym_end];
                const my_pair = vocabs[i..next_sym_end]; // Nếu thấy xuất hiện `pair` ở vị trí `i`

                if (std.mem.eql(u8, pair, my_pair)) {
                    // thì thay thế `pair` vào vị trí `i`
                    syms_len[i] = @intCast(u8, pair.len);
                    // và loại bỏ count của cặp ngay trước `pair`.
                    if (prev_sym >= key_begin) {
                        const prev_pair = vocabs[prev_sym..sym_end];
                        const e = self.pairs_count.get_entry(prev_pair);
                        if (e != null) e.?.count -= key_count;

                        const new_pair = vocabs[prev_sym .. i + syms_len[i]];
                        const idx = self.pairs_count.put_count(new_pair, key_count);
                        if (self.pairs_count.entries[idx].count == key_count) {
                            self.candidates[self.total_candidates] = idx;
                            self.total_candidates += 1;
                        }
                        if (show_info) std.debug.print("prev[{s}]:`{s}`-`{s}` \t", .{ pair, prev_pair, new_pair });
                    }

                    // rồi loại bỏ count của cặp ngay sau `pair`
                    // if (show_info) std.debug.print("{s}-{s}-{s} \t", .{ vocabs[i..key_end], vocabs[i..sym_end], vocabs[sym_end..next_sym_end] });
                    if (next_sym_end < key_end) {
                        const next_pair_end = next_sym_end + syms_len[next_sym_end];
                        const next_pair = vocabs[sym_end..next_pair_end];

                        const e = self.pairs_count.get_entry(next_pair);
                        if (e != null) e.?.count -= key_count;

                        const new_pair = vocabs[i..next_pair_end];
                        const idx = self.pairs_count.put_count(new_pair, key_count);
                        if (self.pairs_count.entries[idx].count == key_count) {
                            self.candidates[self.total_candidates] = idx;
                            self.total_candidates += 1;
                        }
                        if (show_info) std.debug.print("next[{s}]:`{s}`-`{s}`\t", .{ pair, next_pair, new_pair });
                    }
                }
                //
            } else if (sym_end > key_end) { // có lỗi
                //
                std.debug.print("\n>> sym_end:{d} > key_end:{} <<\n", .{ sym_end, key_end });
                std.debug.print("sym:`{s}`\n", .{vocabs[i..sym_end]});
                // std.debug.print("key:`{s}` my_pair:`{s}`\n", .{ key, my_pair });
                unreachable;
            }

            // next symbol
            prev_sym = i;
            i = sym_end;

            if (i == prev_sym) {
                const key = vocabs[i..key_end];
                std.debug.print("\n>> Bị đứng ở marking `{s}` <<\n", .{pair});
                std.debug.print("key:`{s}` my_pair:`{s}`\n", .{ key, my_pair });
                unreachable;
            }

            if (i == key_end) {
                i += 3; // next key
                if (i < vocabs.len) {
                    key_count = vocabs[i - 3] * @as(u32, 256) + vocabs[i - 2];
                    key_end = i + vocabs[i - 1];
                    prev_sym = dont_exist;
                    key_begin = i;
                    continue;
                }
            }
        }
        // std.debug.print("\n>> Marking `{s}` done! <<\n", .{pair});
    }

    pub fn showSelected(self: *Self, n: usize) void {
        std.debug.print("\n\n(( BPE selected symbols ))\n\n", .{});
        for (self.selected_symbols[0..self.total_selected]) |entry, i| {
            if (i == n) break;
            const key = self.pairs_count.key_str(entry.offset);
            std.debug.print("'{s}':{d} \t", .{ key, entry.count });
        }

        std.debug.print("\n\nTOTAL: {d} symbols\n", .{self.pairs_count.len});
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.symbols_len);
        self.allocator.free(self.selected_symbols);
        self.allocator.free(self.candidates);
        self.pairs_count.deinit();
        self.chars_count.deinit();
    }
    pub fn init(self: *Self, init_allocator: std.mem.Allocator, vocabs: []const u8) !void {
        self.allocator = init_allocator;

        // Đầu vào `vocabs` là chuỗi byte lưu key và it's count theo format dưới:
        // \count-byte1\count-byte2\len\'key'...
        self.vocabs = vocabs;

        // Đây là mảng lưu độ dài của symbol đang có mặt trong key
        // dùng để đánh dấu khi nhập các symbols lại thành pair
        self.symbols_len = try self.allocator.alloc(u8, vocabs.len);
        std.mem.set(u8, self.symbols_len[0..], 0);

        // HashCount để tính số lượng các symbols đang thống kê
        try self.pairs_count.init(self.allocator);

        // Đầu ra là thống kê các utf-8 chars và it's count có trong vocabs
        try self.chars_count.init(self.allocator);

        // Mảng các ứng viên
        self.candidates = try self.allocator.alloc(usize, max_total_symbols);
        self.total_candidates = 0;

        // Đầu ra là các pairs được chọn dựa trên thuật toán BPE
        self.total_selected = 0;
        self.selected_symbols = try self.allocator.alloc(shc.Entry, max_total_symbols);

        var x: usize = 0;
        self.total_keys = 0; // dùng để đếm số lượng keys có trong vocabs

        while (x < vocabs.len) {
            const key_count = vocabs[x] * @as(u16, 256) + vocabs[x + 1];
            x += 2; // bỏ qua 2-bytes lưu count
            const key_len = vocabs[x];
            x += 1; // trỏ tới đầu key
            var key_end = x + key_len;
            // const key = vocabs[x .. key_end];
            self.total_keys += 1;

            // std.debug.print("\n{d} `{s}` ", .{ key_end - x, vocabs[x..key_end] });

            while (x < key_end) {
                // Dùng mảng symbols_len để đánh dấu độ dài theo bytes của curr symbol
                switch (vocabs[x]) {
                    0b0000_0000...0b0111_1111 => self.symbols_len[x] = 1,
                    0b1100_0000...0b1101_1111 => self.symbols_len[x] = 2,
                    0b1110_0000...0b1110_1111 => self.symbols_len[x] = 3,
                    0b1111_0000...0b1111_0111 => self.symbols_len[x] = 4,
                    else => { // error.Utf8InvalidStartByte
                        // treat phần còn lại của key là chuỗi byte
                        std.mem.set(u8, self.symbols_len[x..key_end], 1);
                        // bỏ qua phần còn lại của key
                        // self.symbols_len[x] = @intCast(u8, key_end - x);
                        x = key_end;
                        break;
                    },
                }
                const symbol_end = x + self.symbols_len[x];
                if (symbol_end > key_end) {
                    // Lỗi ko đủ byte cho symbol
                    // treat phần còn lại của key là chuỗi byte
                    std.mem.set(u8, self.symbols_len[x..key_end], 1);
                    // bỏ qua phần còn lại của key
                    // self.symbols_len[x] = @intCast(u8, key_end - x);
                    x = key_end;
                    break;
                }
                const symbol = vocabs[x..symbol_end];
                // Thống kê lại các symbols là chars
                _ = self.chars_count.put_count(symbol, key_count);
                // std.debug.print("{s}:{d}:{d} ", .{ symbol, symbol.len, entry.count });
                x = symbol_end;
            } // x < key_end
        } // vocabs
    }
};
