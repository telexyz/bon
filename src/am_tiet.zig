const std = @import("std");
const sds = @import("syllable.zig"); // sds: Syllable Data Structures
const getInitial = @import("am_dau.zig").getInitial;

const getMiddle = @import("am_giua.zig").getMiddle;
const getSingleMiddle = @import("am_giua.zig").getSingleMiddle;

const getFinal = @import("am_cuoi.zig").getFinal;
const isFinalConsonant = @import("am_cuoi.zig").isFinalConsonant;

const Char = @import("ky_tu.zig").Char;
const cmn = @import("common.zig");

fn _parse(bytes: []const u8) void {
    cmn.printSyllParts(bytes, parseSyllable(bytes));
}

pub fn main() void {
    cmn.printSyllTableHeaders();

    _parse("GÀN");
    _parse("GặN");
    _parse("GIừp");
    _parse("nGhiÊng");
    _parse("nGiêng");
    _parse("đim");
    _parse("gĩmmmm");
    _parse("ĩm");

    _parse("nghúýếng");
    _parse("giếng");
    _parse("đ");
    _parse("g");
    _parse("gĩ");
    _parse("ginh");
    _parse("gim");
    _parse("giâ");
    _parse("a");
}

const MAX_SYLL_BYTES_LEN = 12;

pub fn parseSyllable(bytes: []const u8) sds.Syllable {
    var syll = sds.Syllable.new();
    // chuỗi rỗng hoặc lớn hơn 10 bytes không phải âm tiết utf8
    if (bytes.len == 0 or bytes.len > MAX_SYLL_BYTES_LEN) return syll;

    const bytes_len = bytes.len;
    var c0: Char = undefined;
    var c1: Char = undefined;

    // phân tách ký tự đầu tiên
    c0.parse(bytes, 0);
    var idx = c0.len;

    // PHÂN TÍCH PHỤ ÂM ĐẦU
    if (!c0.vowel) { // ko phải nguyên âm
        if (idx == bytes_len) return syll; // không có phụ âm

        if (c0.byte1 == 196 and c0.byte0 == 145) { // mà độ dài 2-byte thì có khả năng là `đ`
            syll.am_dau = .zd; // đ'196:145
        } else { // lấy thêm 1 ký tự nữa để kiểm tra phụ âm đôi
            c1.parse(bytes, idx);
            idx += c1.len;
            syll.am_dau = getInitial(c0.byte0, c1.byte0);
        }

        // bỏ qua h của ngh
        if (syll.am_dau == .ng and idx < bytes_len and
            (bytes[idx] == 'h' or bytes[idx] == 'H')) idx += 1;

        // gi nhưng i là âm giữa vì âm sau là phụ âm cuối
        if (syll.am_dau == .gi) {
            if (idx == bytes_len) { // => `gi`, `gì`, `gỉ`, `gĩ`, `gị`
                syll.am_dau = .g;
                syll.am_giua = .i;
                syll.tone = c1.tone;
                syll.am_cuoi = ._none;
                return syll;
            }
            if (isFinalConsonant(bytes[idx])) {
                if (bytes_len > idx + 2) return syll; // không có final nào > 2-bytes
                syll.am_dau = .g;
                syll.am_giua = .i;
                syll.tone = c1.tone;

                const curr = 0b00100000 | bytes[idx];
                idx += 1;
                if (idx < bytes_len) syll.am_cuoi = getFinal(curr, 0b00100000 | bytes[idx]) else syll.am_cuoi = getFinal(0, curr);
                return syll;
            }
        }
    }

    // PHÂN TÍCH ÂM GIỮA
    switch (syll.am_dau.len()) {
        // 0 => { // không có âm đầu
        // },
        1 => { // âm đầu 1 ký tự => sử dụng lại c1
            c0 = c1;
        },
        2 => { // âm đầu 2 ký tự
            c0.parse(bytes, idx);
            idx += c0.len;
        },
        else => {},
    }

    if (idx == bytes_len) { // âm giữa một ký tự
        syll.am_giua = getSingleMiddle(c0.byte0, c0.byte1);
        c1.tone = ._none;
    } else { // âm giữa có thể có 2 ký tự
        c1.parse(bytes, idx);
        idx += c1.len;

        if ((c0.byte0 == 'u' and c1.byte0 == 'y') or
            (c0.byte1 == 0 and c0.byte0 == 'o' and c1.byte1 == 0 and
            (c1.byte0 == 'a' or c1.byte0 == 'e' or c1.byte0 == 'o')))
        {
            // oa, // hoa
            // oe, // toe
            // oo, // boong
            // uy, // tuy
            c0.byte1 = c0.byte0;
            c0.byte0 = c1.byte0;
            c1.parse(bytes, idx);
            idx += c1.len;
        }
        syll.am_giua = getMiddle(c0.byte0, c0.byte1, c1.byte0, c1.byte1);
    }

    // XÁC ĐỊNH THANH ĐIỆU
    syll.tone = c0.tone;
    if (syll.tone == ._none) syll.tone = c1.tone;

    // PARSE ÂM CUỐI
    var valid_final = true;
    var no_more = false;

    if (syll.am_giua.len() < 3) { // nguyên âm đơn
        // std.debug.print("\n >> sử dụng lại char của phân tích âm giữa << \n", .{});
        c0 = c1;
    } else if (idx < bytes_len) {
        // parse char mới
        c0.parse(bytes, idx);
        idx += c0.len;
    } else {
        no_more = true;
        valid_final = true;
        syll.am_cuoi = ._none;
    }

    // khả năng âm cuối có hai ký tự
    if (idx < bytes_len) {
        // std.debug.print("\n >> âm cuối có thêm 1 ký tự nữa << \n", .{});
        c1.parse(bytes, idx);
        idx += c1.len;
        if (idx < bytes_len) {
            // phần còn lại có nhiều hơn 2 ký tự
            syll.am_cuoi = ._none;
            valid_final = false;
        } else {
            syll.am_cuoi = getFinal(c0.byte0, c1.byte0);
            valid_final = (syll.am_cuoi != ._none); // parse không ra
        }
    } else if (!no_more) {
        // khả năng âm cuối có 1 ký tự
        syll.am_cuoi = getFinal(0, c0.byte0);
        valid_final = (syll.am_cuoi != ._none);
    }

    // TODO: cần check can_be_vietnamese từ khâu initial và middle
    syll.can_be_vietnamese = valid_final;

    return syll;
}
