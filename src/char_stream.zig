const std = @import("std");
const parseSyllable = @import("am_tiet.zig").parseSyllable;
const cmn = @import("common.zig");

// Dùng Zig Vector type và các Vector operators để Zig tự động dịch sang
// SIMD code, tự động dùng 256-bit lane (AVX) hoặc 512-bit lane (AVX-512)

const VecType = std.meta.Vector(BYTES_PROCESSED, u8);
const BitType = u64;

const BYTES_PROCESSED = 64;
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

inline fn getIsNonAlphabetAsciiBits(vec: VecType) BitType {
    var results = @ptrCast(*const BitType, &(vec < A_vec)).*;

    results |= @ptrCast(*const BitType, &(vec > Z_vec)).* &
        @ptrCast(*const BitType, &(vec < a_vec)).*;

    results |= @ptrCast(*const BitType, &(vec > z_vec)).* &
        @ptrCast(*const BitType, &(vec <= max_ascii_vec)).*;

    return results;
}

const idx_bits: []const BitType = &.{ 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 1 << 11, 1 << 12, 1 << 13, 1 << 14, 1 << 15, 1 << 16, 1 << 17, 1 << 18, 1 << 19, 1 << 20, 1 << 21, 1 << 22, 1 << 23, 1 << 24, 1 << 25, 1 << 26, 1 << 27, 1 << 28, 1 << 29, 1 << 30, 1 << 31, 1 << 32, 1 << 33, 1 << 34, 1 << 35, 1 << 36, 1 << 37, 1 << 38, 1 << 39, 1 << 40, 1 << 41, 1 << 42, 1 << 43, 1 << 44, 1 << 45, 1 << 46, 1 << 47, 1 << 48, 1 << 49, 1 << 50, 1 << 51, 1 << 52, 1 << 53, 1 << 54, 1 << 55, 1 << 56, 1 << 57, 1 << 58, 1 << 59, 1 << 60, 1 << 61, 1 << 62, 1 << 63 };

fn inSet(bits: BitType, idx: usize) bool {
    return (idx_bits[idx] & bits) != 0;
}

pub fn main() !void {
    // cwd(): curr_bytesent working directory
    var file = try std.fs.cwd().openFile("utf8tv.txt", .{});
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
        std.debug.print("\n\nbuf[{d}]: \"{s}\"", .{ count, curr_bytes[0..len] });

        vec = curr_bytes.*;
        const sp_bits = getIsNonAlphabetAsciiBits(vec);
        sp_idx = @ctz(BitType, sp_bits);
        if (sp_idx > len) sp_idx = len;

        if (tk_idx != TOKEN_PROCESSED) {
            // token đầu tiên của curr_bytes nằm trên prev_bytes

            var bytes: [2 * BYTES_PROCESSED]u8 = undefined;
            const prev_ = prev_bytes[tk_idx..];
            const curr_ = curr_bytes[0..sp_idx];

            std.mem.copy(u8, bytes[0..], prev_);
            std.mem.copy(u8, bytes[prev_.len..], curr_);
            const token = bytes[0..(prev_.len + curr_.len)];

            std.debug.print("\n{d:0>2}-{d:0>2}: {s: >12}", .{
                tk_idx, sp_idx, token,
                // prev_bytes[tk_idx..], curr_bytes[0..sp_idx],
            });

            const syll = parseSyllable(token);
            if (syll.can_be_vietnamese) cmn.printSyllParts(syll);
            //
        } else if (sp_idx != 0) {
            // token đầu tiên của curr_bytes không nằm trên prev_bytes
            printToken(0, sp_idx, curr_bytes);
        }

        //
        if (sp_idx == len) tk_idx = len;

        while (sp_idx < len) {
            // Tìm next token index
            while (sp_idx < len and inSet(sp_bits, sp_idx)) sp_idx += 1;
            tk_idx = sp_idx;

            // Tìm next space index
            while (sp_idx < len and !inSet(sp_bits, sp_idx)) sp_idx += 1;

            if (sp_idx < len)
                printToken(tk_idx, sp_idx, curr_bytes);
        }

        // swap curr_bytes and prev_bytes
        const tmp = curr_bytes;
        curr_bytes = prev_bytes;
        prev_bytes = tmp;

        // đọc đoạn dữ liệu tiếp theo
        len = try in_stream.read(curr_bytes);
        count += 1;
    }
}

inline fn printToken(token_idx: usize, space_idx: usize, curr_bytes: []const u8) void {
    const bytes = curr_bytes[token_idx..space_idx];
    std.debug.print("\n{d:0>2}-{d:0>2}: {s: >12}", .{
        token_idx,
        space_idx,
        bytes,
    });

    const syll = parseSyllable(bytes);
    if (syll.can_be_vietnamese) cmn.printSyllParts(syll);
}
