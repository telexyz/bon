pub const DEBUGGING = false;

const std = @import("std");
const sds = @import("syllable.zig"); // sds: Syllable Data Structures
const Char = @import("ky_tu.zig").Char;
const SEP_LINE = "\n - - - - - - - - - - - - - - - - - - - - -";

pub fn printSyllTableHeaders() void {
    std.debug.print("\n{s: >11}: {s: >5} {s: >5} {s: >5} {s: >5} {s: >5}", .{ "ÂM TIẾT", "ĐẦU", "GIỮA", "CUỐI", "THANH", "CBVN" });
    printSepLine();
}

pub fn printSepLine() void {
    std.debug.print(SEP_LINE, .{});
}

pub fn printSyllParts(bytes: []const u8, syll: sds.Syllable) void {
    std.debug.print("\n{s: >11}: {s: >5} {s: >5} {s: >5} {s: >5} {: >5}", .{ bytes, @tagName(syll.am_dau), @tagName(syll.am_giua), @tagName(syll.am_cuoi), @tagName(syll.tone), syll.can_be_vietnamese });
    if (DEBUGGING) printSepLine();
}

pub fn showChatAt(bytes: []const u8, curr: usize) void {
    const curr_is_ascii = bytes[curr] < 128;
    const next = curr + 1;

    // không phải ascii mà không còn byte tiếp theo để phân tích
    if (!curr_is_ascii and next == bytes.len) return;

    var char = if (curr_is_ascii) bytes[curr .. curr + 1] else bytes[curr .. next + 1];
    if (bytes[curr] == 225) char = bytes[curr .. curr + 3]; // utf8 3-byte char
    std.debug.print("\nbytes[{d:0>2}] = {s: >2} {d: >3}:{d: >3}", //
        .{ curr, char, bytes[curr], if (next < bytes.len) bytes[next] else 32 });
}

pub fn showChar(char: *Char) void {
    const str: []const u8 = &.{ char.byte1, char.byte0 };
    std.debug.print(" >> {s} {d:0>3}:{d:0>3}", .{ str, char.byte1, char.byte0 });
}