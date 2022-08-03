const std = @import("std");
const v = @import("vector_types.zig");

// Dùng Zig Vector type và các operators trước khi tự cài SIMD
// const simd = @import("simd.zig");

const BYTES_PROCESSED = 32;
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

inline fn getIsNonAlphabetAsciiBits(vec: v.u8x32) u32 {
    var results = @ptrCast(*const u32, &(vec < A_vec)).*;
    // results |= (vec > Z_vec) & (vec < a_vec);
    // results |= (vec > z_vec) & (vec <= max_ascii_vec);
    return results;
}

const idx_bits: []const u32 = &.{ 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 1 << 11, 1 << 12, 1 << 13, 1 << 14, 1 << 15, 1 << 16, 1 << 17, 1 << 18, 1 << 19, 1 << 20, 1 << 21, 1 << 22, 1 << 23, 1 << 24, 1 << 25, 1 << 26, 1 << 27, 1 << 28, 1 << 29, 1 << 30, 1 << 31 };

fn inSet(bits: u32, idx: usize) bool {
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

    var vec: v.u8x32 = undefined;
    var token_idx: usize = TOKEN_PROCESSED;
    var space_idx: usize = undefined;
    // token đang xử lý sẽ nằm từ token_idx .. space_idx

    // đọc dữ liệu lần đầu tiên
    var len = try in_stream.read(curr_bytes);
    var count: usize = 0;

    while (len > 0) {
        // cần prev_bytes_bytes vì 1 ký tự utf8 (2-4 bytes) hoặc một token nằm ngay
        // giữa đoạn cắt khi đọc dữ liệu theo từng BYTES_PROCESSED
        // => curr_bytes lưu nửa sau của utf8-char hoặc token
        //    prev_bytes lưu nửa đầu của utf8-char hoặc token
        std.debug.print("\nbuf[{d}]: \"{s}\"\n", .{ count, curr_bytes[0..len] });

        vec = curr_bytes.*;

        const sp_bits = getIsNonAlphabetAsciiBits(vec);
        space_idx = @ctz(u32, sp_bits);

        if (token_idx != TOKEN_PROCESSED) {
            // token đầu tiên của curr_bytes nằm trên prev_bytes
            std.debug.print("{d:0>2}-{d:0>2}: {s}{s}\n", .{
                token_idx,               space_idx,
                prev_bytes[token_idx..], curr_bytes[0..space_idx],
            });
        } else if (space_idx != 0) {
            // token đầu tiên của curr_bytes không nằm trên prev_bytes
            printToken(0, space_idx, curr_bytes);
        }

        while (space_idx < len) {
            // Tìm next token index
            while (space_idx < len and inSet(sp_bits, space_idx)) space_idx += 1;
            token_idx = space_idx;

            // Tìm next space index
            while (space_idx < len and !inSet(sp_bits, space_idx)) space_idx += 1;

            if (space_idx < len)
                printToken(token_idx, space_idx, curr_bytes);
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
    std.debug.print("{d:0>2}-{d:0>2}: {s}\n", .{
        token_idx,
        space_idx,
        curr_bytes[token_idx..space_idx],
    });
}
