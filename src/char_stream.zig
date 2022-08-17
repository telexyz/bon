const std = @import("std");
const builtin = @import("builtin");
const parseSyllable = @import("am_tiet.zig").parseSyllable;
const cmn = @import("common.zig");
const shc = @import("str_hash_count.zig");
const BPE = @import("byte_pair_encode.zig").BPE;
const SyllableCount = @import("syllable_count.zig").SyllableCount;
// Init HashCount để count các tokens ko phải âm tiết tiếng Việt
pub const NotSyllHashCount = shc.HashCount(2_500_000);

var type_counters: NotSyllHashCount = undefined; // dùng chung cho nhiều threads
var syll_counters: SyllableCount = undefined;

// Dùng Zig Vector type và các Vector operators để Zig tự động dịch sang
// SIMD code, tự động dùng 256-bit lane (AVX) hoặc 512-bit lane (AVX-512)

const VecType = std.meta.Vector(BYTES_PROCESSED, u8);
const BitType = std.meta.Int(.unsigned, BYTES_PROCESSED);

const BYTES_PROCESSED = 64; // bytes
const TOKEN_PROCESSED = BYTES_PROCESSED;

const A_byte: u8 = 'A';
const Z_byte: u8 = 'Z';
const a_byte: u8 = 'a';
const z_byte: u8 = 'z';
const max_ascii_byte: u8 = 127;

const A_vec = @splat(BYTES_PROCESSED, A_byte);
const Z_vec = @splat(BYTES_PROCESSED, Z_byte);
const a_vec = @splat(BYTES_PROCESSED, a_byte);
const z_vec = @splat(BYTES_PROCESSED, z_byte);
const max_ascii_vec = @splat(BYTES_PROCESSED, z_byte);

fn getIsNonAlphabetAsciiBits(vec: VecType) BitType {
    var results = @ptrCast(*const BitType, &(vec < A_vec)).*;

    results |= @ptrCast(*const BitType, &(vec > Z_vec)).* &
        @ptrCast(*const BitType, &(vec < a_vec)).*;

    results |= @ptrCast(*const BitType, &(vec > z_vec)).* &
        @ptrCast(*const BitType, &(vec <= max_ascii_vec)).*;

    return results;
}

const idx_bits: []const u64 = &.{ 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 1 << 11, 1 << 12, 1 << 13, 1 << 14, 1 << 15, 1 << 16, 1 << 17, 1 << 18, 1 << 19, 1 << 20, 1 << 21, 1 << 22, 1 << 23, 1 << 24, 1 << 25, 1 << 26, 1 << 27, 1 << 28, 1 << 29, 1 << 30, 1 << 31, 1 << 32, 1 << 33, 1 << 34, 1 << 35, 1 << 36, 1 << 37, 1 << 38, 1 << 39, 1 << 40, 1 << 41, 1 << 42, 1 << 43, 1 << 44, 1 << 45, 1 << 46, 1 << 47, 1 << 48, 1 << 49, 1 << 50, 1 << 51, 1 << 52, 1 << 53, 1 << 54, 1 << 55, 1 << 56, 1 << 57, 1 << 58, 1 << 59, 1 << 60, 1 << 61, 1 << 62, 1 << 63 };

inline fn inSet(bits: BitType, idx: usize) bool {
    std.debug.assert(BitType == u64);
    return (idx_bits[idx] & bits) != 0;
}
// inline fn inSet(bits: *const BitType, idx: usize) bool {
//     const _u64s = @ptrCast(*const [BYTES_PROCESSED / 64]u64, bits).*;
//     return (idx_bits[idx % 64] & _u64s[idx / 64]) != 0;
// }

fn scanFile(file_name: []const u8) !void {
    // cwd(): curr_bytesent working directory
    var file = try std.fs.cwd().openFile(file_name, .{});
    defer file.close();

    // sử dụng bufferred reader để tăng tốc độ đọc file
    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    // sử dụng 2 buffers để lưu dữ liệu đọc từ file
    var buf1: [BYTES_PROCESSED]u8 = undefined;
    var buf2: [BYTES_PROCESSED]u8 = undefined;

    var curr_bytes = buf1[0..]; // khởi tạo current buffer
    var prev_bytes = buf2[0..]; // khởi tạo previous buffer

    var vec: VecType = undefined;
    var tk_idx: usize = TOKEN_PROCESSED; // token index
    var sp_idx: usize = undefined; // separator index
    // token đang xử lý sẽ nằm từ token_idx .. sp_idx

    // đọc dữ liệu lần đầu tiên
    var len = try in_stream.read(curr_bytes);
    var count: usize = 0;

    while (len > 0) {
        // cần prev_bytes_bytes vì 1 ký tự utf8 (2-4 bytes) hoặc một token nằm ngay
        // giữa đoạn cắt khi đọc dữ liệu theo từng BYTES_PROCESSED
        // => curr_bytes lưu nửa sau của utf8-char hoặc token
        //    prev_bytes lưu nửa đầu của utf8-char hoặc token

        if (show_info)
            std.debug.print("\n\nbuf[{d}]: \"{s}\"", .{ count, curr_bytes[0..len] });

        vec = curr_bytes.*;
        const sp_bits = getIsNonAlphabetAsciiBits(vec);
        sp_idx = @ctz(BitType, sp_bits);
        if (sp_idx > len) sp_idx = len;

        if (tk_idx != TOKEN_PROCESSED) {
            // token đầu tiên của curr_bytes nằm trên prev_bytes

            // TODO: thay vì dùng buff mới thì mở rộng curr và prev để
            // tiết kiệm 1 lần mem.copy
            var bytes: [2 * BYTES_PROCESSED]u8 = undefined;
            const prev_ = prev_bytes[tk_idx..];
            const curr_ = curr_bytes[0..sp_idx];

            std.mem.copy(u8, bytes[0..], prev_);
            std.mem.copy(u8, bytes[prev_.len..], curr_);
            const token = bytes[0..(prev_.len + curr_.len)];

            processToken(tk_idx, sp_idx, token);
            //
        } else if (sp_idx != 0) {
            // token đầu tiên của curr_bytes không nằm trên prev_bytes
            processToken(0, sp_idx, curr_bytes[0..sp_idx]);
        }

        //
        if (sp_idx == len) tk_idx = len;

        while (sp_idx < len) {
            // Tìm next token index
            while (sp_idx < len and inSet(sp_bits, sp_idx)) sp_idx += 1;
            tk_idx = sp_idx;

            // Tìm next space index
            while (sp_idx < len and !inSet(sp_bits, sp_idx)) sp_idx += 1;

            if (sp_idx < len) processToken(tk_idx, sp_idx, curr_bytes[tk_idx..sp_idx]);
        }

        // swap curr_bytes and prev_bytes
        const tmp = curr_bytes;
        curr_bytes = prev_bytes;
        prev_bytes = tmp;

        // đọc đoạn dữ liệu tiếp theo
        len = try in_stream.read(curr_bytes);
        count += 1;
    }

    std.debug.print("\n(( `{s}` scanned. ))\n", .{file_name});
}

fn processToken(token_idx: usize, space_idx: usize, token: []const u8) void {
    if (show_info)
        std.debug.print("\n{d:0>2}-{d:0>2}: {s: >12}", .{
            token_idx,
            space_idx,
            token,
        });

    var syll = parseSyllable(token);

    if (syll.can_be_vietnamese)
        syll_counters.put(syll.toId())
    else
        type_counters.put(token);

    if (show_info) cmn.printSyllParts(syll);
}

pub fn main() !void {
    try type_counters.init(std.heap.page_allocator);
    defer type_counters.deinit();

    try syll_counters.init(std.heap.page_allocator);
    defer syll_counters.deinit();

    switch (builtin.mode) {
        .Debug, .ReleaseSmall => {
            // show_info = true;
            try scanFile("utf8tv.txt");
            try scanFile("../data/fb_comments_0.txt");
            // try scanFile("../data/news_titles.txt");
            // try scanFile("../data/vi_wiki_all.txt");
        },
        .ReleaseSafe => {
            try scanFile("../data/fb_comments.txt");
            try scanFile("../data/news_titles.txt");
            try scanFile("../data/vi_wiki_all.txt");
            // try scanFile("../data/vietai_sat.txt");
        },
        .ReleaseFast => {
            // Chạy 4 threads giúp tăng tốc gấp đôi (Intel Duo-Core)
            // - - - - - - - - - - - - - - - - - -
            // var thread3 = try std.Thread.spawn(.{}, scanFile, .{"../data/vi_wiki_all.txt"});
            // var thread2 = try std.Thread.spawn(.{}, scanFile, .{"../data/vietai_sat.txt"});
            // var thread1 = try std.Thread.spawn(.{}, scanFile, .{"../data/news_titles.txt"});
            try scanFile("../data/fb_comments.txt");
            // thread1.join();
            // thread2.join();
            // thread3.join();
        },
    }

    syll_counters.list(20);
    var count_desc: shc.CountDesc = undefined;
    defer count_desc.deinit();
    try count_desc.init(std.heap.page_allocator, type_counters.len, type_counters.entries, type_counters.keys_bytes, type_counters.keys_bytes_len);
    count_desc.list(80);
    type_counters.showStats();

    var bpe: BPE = undefined;
    defer bpe.deinit();
    try bpe.init(std.heap.page_allocator, count_desc.vocabs_slice());
    try bpe.learn();
    bpe.showSelected(100);
}

// simple config
var show_info = false;
