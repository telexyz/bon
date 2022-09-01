const std = @import("std");
const builtin = @import("builtin");
const parseSyllable = @import("am_tiet.zig").parseSyllable;
const cmn = @import("common.zig");
const shc = @import("str_hash_count.zig");
const BPE = @import("byte_pair_encoding.zig").BPE;
const SyllableCount = @import("syllable_count.zig").SyllableCount;
// Init HashCount để count các tokens ko phải âm tiết tiếng Việt
pub const NotSyllHashCount = shc.HashCount(2_500_000);

var type_counters: NotSyllHashCount = undefined; // dùng chung cho nhiều threads
var syll_counters: SyllableCount = undefined;

// Dùng Zig Vector type và các Vector operators để Zig tự động dịch sang
// SIMD code, tự động dùng 256-bit lane (AVX) hoặc 512-bit lane (AVX-512)

const VecType = std.meta.Vector(MAX_READ_BYTES, u8);
const BitType = std.meta.Int(.unsigned, MAX_READ_BYTES);

const MAX_READ_BYTES = 64; // bytes

const A_byte: u8 = 'A';
const Z_byte: u8 = 'Z';
const a_byte: u8 = 'a';
const z_byte: u8 = 'z';
const max_ascii_byte: u8 = 127;

const A_vec = @splat(MAX_READ_BYTES, A_byte);
const Z_vec = @splat(MAX_READ_BYTES, Z_byte);
const a_vec = @splat(MAX_READ_BYTES, a_byte);
const z_vec = @splat(MAX_READ_BYTES, z_byte);
const max_ascii_vec = @splat(MAX_READ_BYTES, z_byte);

inline fn getIsNonAlphabetAsciiBits(vec: VecType) BitType {
    var results = @ptrCast(*const BitType, &(vec < A_vec)).*;

    results |= @ptrCast(*const BitType, &(vec > Z_vec)).* &
        @ptrCast(*const BitType, &(vec < a_vec)).*;

    results |= @ptrCast(*const BitType, &(vec > z_vec)).* &
        @ptrCast(*const BitType, &(vec <= max_ascii_vec)).*;

    return results;
}

const idx_bits: []const u64 = &.{ 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 1 << 11, 1 << 12, 1 << 13, 1 << 14, 1 << 15, 1 << 16, 1 << 17, 1 << 18, 1 << 19, 1 << 20, 1 << 21, 1 << 22, 1 << 23, 1 << 24, 1 << 25, 1 << 26, 1 << 27, 1 << 28, 1 << 29, 1 << 30, 1 << 31, 1 << 32, 1 << 33, 1 << 34, 1 << 35, 1 << 36, 1 << 37, 1 << 38, 1 << 39, 1 << 40, 1 << 41, 1 << 42, 1 << 43, 1 << 44, 1 << 45, 1 << 46, 1 << 47, 1 << 48, 1 << 49, 1 << 50, 1 << 51, 1 << 52, 1 << 53, 1 << 54, 1 << 55, 1 << 56, 1 << 57, 1 << 58, 1 << 59, 1 << 60, 1 << 61, 1 << 62, 1 << 63 };

pub inline fn inSet(bits: anytype, idx: usize) bool {
    return (idx_bits[idx] & bits) != 0;
}

fn scanFile(file_name: []const u8) !void {
    // cwd(): curr_bytesent working directory
    var file = try std.fs.cwd().openFile(file_name, .{});
    defer file.close();

    // sử dụng bufferred reader để tăng tốc độ đọc file
    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    // sử dụng 2 buffers lưu dữ liệu đọc từ file để xử lý token nằm ở ranh giới
    var curr_buf: [2 * MAX_READ_BYTES]u8 = undefined;
    var prev_buf: [2 * MAX_READ_BYTES]u8 = undefined;

    var tk_idx: usize = MAX_READ_BYTES; // token index
    var sp_idx: usize = 0; // separator index
    var prev_sp_idx: usize = 0;
    // token đang xử lý sẽ nằm từ token_idx .. sp_idx

    var count: usize = 0;
    while (true) : (count += 1) {

        // swap curr_bytes and prev_bytes
        const tmp = curr_buf;
        curr_buf = prev_buf;
        prev_buf = tmp;

        // đọc dữ liệu
        const curr_bytes = curr_buf[MAX_READ_BYTES..];
        const len = try in_stream.read(curr_bytes);
        if (len == 0) break;

        // cần prev_bytes_bytes vì 1 ký tự utf8 (2-4 bytes) hoặc một token nằm ngay
        // giữa đoạn cắt khi đọc dữ liệu theo từng MAX_READ_BYTES
        // => curr_bytes lưu nửa sau của utf8-char hoặc token
        //    prev_bytes lưu nửa đầu của utf8-char hoặc token

        if (show_info) std.debug.print("\n\nbuf[{d}]: \"{s}\"", .{ count, curr_bytes[0..len] });
        const sp_bits = getIsNonAlphabetAsciiBits(curr_bytes.*);
        var next_sp_idx: usize = @ctz(BitType, sp_bits);
        if (next_sp_idx > len) next_sp_idx = len; // normalized

        const non_alpha_tokens_between_buffers = (sp_idx == MAX_READ_BYTES);
        if (show_info) std.debug.print("\n{d} {d} {d} | {d}", .{ prev_sp_idx, sp_idx, next_sp_idx, tk_idx });

        sp_idx = 0;
        while (sp_idx < len and inSet(sp_bits, sp_idx)) sp_idx += 1;

        if (tk_idx != MAX_READ_BYTES) {
            // Nửa đầu token đầu tiên của curr_bytes nằm trên prev_bytes
            const first_half = prev_buf[MAX_READ_BYTES + tk_idx ..];
            const bytes = curr_buf[MAX_READ_BYTES - first_half.len .. MAX_READ_BYTES + next_sp_idx];
            std.mem.copy(u8, bytes[0..], first_half);
            processToken(bytes);
            //
        } else if (next_sp_idx != 0) {
            // token đầu tiên của curr_bytes bắt đầu ở vị trí số 0
            processToken(curr_bytes[0..next_sp_idx]);
        }

        if (non_alpha_tokens_between_buffers) {
            const first_half = prev_buf[MAX_READ_BYTES + prev_sp_idx ..];
            const bytes = curr_buf[MAX_READ_BYTES - first_half.len .. MAX_READ_BYTES + sp_idx];
            std.mem.copy(u8, bytes[0..], first_half);
            processNonAlphabetTokens(bytes);
            next_sp_idx = sp_idx;
        }

        // Trường hợp đặc biệt
        if (next_sp_idx == len) tk_idx = len;

        while (next_sp_idx < len) {
            // Tìm next non-alphabet tokens
            sp_idx = next_sp_idx;
            prev_sp_idx = sp_idx;
            while (sp_idx < len and inSet(sp_bits, sp_idx)) sp_idx += 1;
            if (sp_idx < len) processNonAlphabetTokens(curr_bytes[prev_sp_idx..sp_idx]);

            // Tìm next alphabet token
            next_sp_idx = sp_idx;
            tk_idx = next_sp_idx;
            while (next_sp_idx < len and !inSet(sp_bits, next_sp_idx)) next_sp_idx += 1;
            if (next_sp_idx < len) processToken(curr_bytes[tk_idx..next_sp_idx]);
        }
    }

    std.debug.print("\n(( `{s}` scanned. ))\n", .{file_name});
}
inline fn processNonAlphabetTokens(str: []const u8) void {
    if (str.len == 0) return;
    var it = std.mem.tokenize(u8, str, " \n\t");
    if (show_info) std.debug.print("\n_ _ _:", .{});
    while (it.next()) |tkn| {
        type_counters.put(tkn);
        if (show_info) std.debug.print(" `{s}`", .{tkn});
    }
}
inline fn processToken(token: []const u8) void {
    var syll = parseSyllable(token);
    if (syll.can_be_vietnamese)
        syll_counters.put(syll.toId())
    else
        type_counters.put(token);

    if (show_info) {
        std.debug.print("\n{s}:\t\t", .{token});
        cmn.printSyllParts(syll);
    }
}

pub fn main() !void {
    // Use c_allocator to run Valgrind mem leak check
    const default_allocator = std.heap.c_allocator;
    // const default_allocator = std.heap.page_allocator;

    defer syll_counters.deinit();
    defer type_counters.deinit();

    try type_counters.init(default_allocator);
    try syll_counters.init(default_allocator);

    switch (builtin.mode) {
        .Debug, .ReleaseSafe => {
            show_info = true;
            try scanFile("utf8tv.txt");
            show_info = false;
        },
        .ReleaseFast, .ReleaseSmall => {
            const start_time = std.time.milliTimestamp();

            // var thread3 = try std.Thread.spawn(.{}, scanFile, .{"../data/vi_wiki_all.txt"});
            // var thread2 = try std.Thread.spawn(.{}, scanFile, .{"../data/vietai_sat.txt"});
            // var thread1 = try std.Thread.spawn(.{}, scanFile, .{"../data/news_titles.txt"});
            // var thread0 = try std.Thread.spawn(.{}, scanFile, .{"../data/fb_comments.txt"});

            var thread3 = try std.Thread.spawn(.{}, scanFile, .{"../data/combined_aa"});
            var thread2 = try std.Thread.spawn(.{}, scanFile, .{"../data/combined_ab"});
            var thread1 = try std.Thread.spawn(.{}, scanFile, .{"../data/combined_ac"});
            var thread0 = try std.Thread.spawn(.{}, scanFile, .{"../data/combined_ad"});
            try scanFile("utf8tv.txt");
            thread0.join();
            thread1.join();
            thread2.join();
            thread3.join();

            const time_spent = @divTrunc(std.time.milliTimestamp() - start_time, 1000);
            std.debug.print("\n[[ TOKENIZATION DONE {d}s ]]\n", .{time_spent});
        },
    }

    switch (builtin.mode) {
        .Debug, .ReleaseFast => {
            syll_counters.list(20);
            syll_counters.deinit();

            var bpe: BPE = undefined;
            defer bpe.deinit();
            const start_time = std.time.milliTimestamp();
            try bpe.init(
                default_allocator,
                type_counters.len,
                type_counters.entries,
                type_counters.keys_bytes,
                type_counters.keys_bytes_len,
            );

            type_counters.showStats();
            type_counters.deinit();

            bpe.listVocabs(bpe.vocabs, bpe.vocabs_len, 300);
            try bpe.learn();
            const time_spent = @divTrunc(std.time.milliTimestamp() - start_time, 1000);
            std.debug.print("\n\n[[ BPE LEARN DONE {d}s ]]\n", .{time_spent});

            bpe.showSelectedSymbols(1000);
            bpe.pairs_count.showStats();
        },
        else => {
            type_counters.showStats();
        },
    }
}

// simple config
var show_info = false;

test "TODO" {
    std.debug.print( //
        "\n\n" ++
        "  * Làm rõ thuật toán scanFile() hiện đang hơi rối\n" ++
        "  * Viết test cases cho char_stream\n" ++
        "\n\n", .{});
}

// test "" {
//     const buf1 = "123456789012345678ngoan9012345mo6789012345678901234567\n890123456";
//     const buf2 = "7dsdsd8901234567890345\n6789012345678sds901d234567890";
//     _ _ _: 6789012345678901234567
//     dsdsd:
//     _ _ _: 8901234567890345 6789012345678
// }
