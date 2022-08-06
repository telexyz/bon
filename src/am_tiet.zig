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
    cmn.printSyllParts(bytes, &parseSyllable(bytes));
}

pub fn main() void {
    cmn.printSyllTableHeaders();

    // _parse("GÀN");
    // _parse("GặN");
    // _parse("GIừp");
    // _parse("nGhiÊng");
    // _parse("nGiêng");
    // _parse("đim");
    // _parse("ĩm");
    // _parse("nghúýếng");
    // _parse("giếng");
    // _parse("gĩ");
    // _parse("ginh");
    // _parse("gim");
    // _parse("giâ");
    // _parse("a");

    // cmn.printSepLine();
    // _parse("gĩmmmm");
    // _parse("đ");
    // _parse("g");
    // _parse("nnnn");

    // cmn.printSepLine();
    // _parse("khủya");
    // _parse("tuảnh");
    // _parse("míach");
    // _parse("dưạng");
    // _parse("duơ");

    // cmn.printSepLine();
    // _parse("qa");
    // _parse("qui");
    // _parse("que");
    // _parse("quy");
    // _parse("cua");
    // _parse("qua");
    // // q chỉ đi với + âm đệm u, có quan điểm `qu` là 1 âm độc lập, quốc vs cuốc
    // _parse("quốc");
    // _parse("cuốc");

    // cmn.printSepLine();
    cmn.DEBUGGING = true;
    _parse("huơ");
}

const MAX_SYLL_BYTES_LEN = 12;

pub fn parseSyllable(bytes: []const u8) sds.Syllable {
    var syll = sds.Syllable.new();
    // chuỗi rỗng hoặc lớn hơn 10 bytes không phải âm tiết utf8
    if (bytes.len == 0 or bytes.len > MAX_SYLL_BYTES_LEN) return syll; // NOT SYLLABLE

    const bytes_len = bytes.len;
    var c0: Char = undefined;
    var c1: Char = undefined;

    // phân tách ký tự đầu tiên
    c0.parse(bytes, 0);
    var idx = c0.len;

    // PHÂN TÍCH PHỤ ÂM ĐẦU
    // - - - - - - - - - -
    if (!c0.vowel) { // ko phải nguyên âm
        // VALIDATE: chỉ có phụ âm đầu
        if (idx == bytes_len) {
            syll.can_be_vietnamese = false; // => vì ko có nguyên âm
            return syll; // NOT SYLLABLE
        }

        if (c0.byte1 == 196 and c0.byte0 == 145) {
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
            syll.tone = c1.tone;
            // std.debug.print("\n>> {} <<\n", .{syll.tone});

            if (idx == bytes_len) { // => `gi`, `gì`, `gỉ`, `gĩ`, `gị`
                syll.am_dau = .g;
                syll.am_giua = .i;
                syll.am_cuoi = ._none;
                syll.can_be_vietnamese = true;
                return syll; // DONE
            }
            if (isFinalConsonant(bytes[idx])) {
                if (bytes_len > idx + 2) return syll; // NOT SYLLABLE
                // không có final nào > 2-bytes

                syll.am_dau = .g;
                syll.am_giua = .i;
                syll.tone = c1.tone;

                // Xác định âm cuối nhanh rồi trả về kết quả
                const curr = 0b00100000 | bytes[idx]; // toLower ascii
                const next = if (idx + 1 < bytes_len) 0b00100000 | bytes[idx + 1] else 0;
                syll.am_cuoi = getFinal(curr, next);
                syll.can_be_vietnamese = syll.am_cuoi != ._none;
                return syll; // DONE
            }
        }
    }

    // PHÂN TÍCH ÂM GIỮA
    // - - - - - - - - -
    switch (syll.am_dau.len()) {
        // 0 => { // không có âm đầu
        // },
        1 => { // âm đầu 1 ký tự => sử dụng lại c1
            if (cmn.DEBUGGING) std.debug.print("\n(( MIDDLE: sử dụng lại `{c}` ))", .{c1.byte0});
            c0 = c1;
        },
        2 => { // âm đầu 2 ký tự
            c0.parse(bytes, idx);
            idx += c0.len;
        },
        else => {},
    }

    if (idx == bytes_len) { // âm giữa một ký tự và ko có âm cuối

        if (cmn.DEBUGGING) std.debug.print("\n(( MIDDLE: âm giữa 1 ký tự và ko có âm cuối))", .{});

        syll.am_giua = if (c0.vowel) // kiểm tra c0 có là nguyên âm k trc khi parse
            getSingleMiddle(c0.byte0, c0.byte1)
        else
            ._none;

        if (c0.tone != ._none) syll.tone = c0.tone;
        syll.am_cuoi = ._none;
        syll.can_be_vietnamese = true;
        return syll; // DONE
    } else { // âm giữa có thể có 2 ký tự

        c1.parse(bytes, idx);
        idx += c1.len;
        if (cmn.DEBUGGING) std.debug.print("\n(( MIDDLE: lấy thêm ký tự `{c}` ))", .{c1.byte0});

        if ((c0.byte0 == 'u' and c1.byte0 == 'y') or
            (c0.byte0 == 'o' and (c1.byte0 == 'a' or c1.byte0 == 'e' or c1.byte0 == 'o')))
        {
            // oa, // hoa
            // oe, // toe
            // oo, // boong
            // uy, // tuy
            c0.byte1 = c0.byte0;
            c0.byte0 = c1.byte0;

            syll.tone = c1.tone;
            if (syll.tone == ._none) syll.tone = c0.tone;

            if (idx == bytes_len) { // không có ký tự tiếp theo
                syll.am_giua = getSingleMiddle(c0.byte0, c0.byte1);
                syll.am_cuoi = ._none;
                syll.can_be_vietnamese = true;
                return syll; // DONE
            } else {
                c1.parse(bytes, idx); //
                idx += c1.len;
            }
        }

        // kiểm tra c0 có là nguyên âm trước khi parse
        syll.am_giua = if (c0.vowel)
            getMiddle(c0.byte0, c0.byte1, c1.byte0, c1.byte1)
        else
            ._none;

        // ưu tiên LẤY THANH ĐIỆU trên nguyên âm thứ 2
        if (c1.tone != ._none) syll.tone = c1.tone;
    }
    // rồi mới LẤY THANH ĐIỆU trên nguyên âm thứ nhất
    if (syll.tone == ._none) syll.tone = c0.tone;

    // VALIDATE: Âm tiết bắt buộc phải có âm giữa
    if (syll.am_giua == ._none) {
        syll.can_be_vietnamese = false;
        return syll; // NOT SYLLABLE
    }

    // PHÂN TÍCH ÂM CUỐI
    // - - - - - - - - -

    // Xác định ký tự thứ nhất của âm cuối
    if (syll.am_giua.len() < 3) { // NẾU là nguyên âm đơn
        c0 = c1; // THÌ sử dụng lại char cuối của phân tích âm giữa
        if (cmn.DEBUGGING) std.debug.print("\n(( FINAL: sử dụng lại `{c}` ))", .{c1.byte0});
    } else if (idx < bytes_len) { // NẾU còn bytes để parse
        c0.parse(bytes, idx); // THÌ parse char mới
        idx += c0.len;
        if (cmn.DEBUGGING) std.debug.print("\n(( FINAL: lấy thêm ký tự `{c}` ))", .{c1.byte0});
    } else {
        if (cmn.DEBUGGING) std.debug.print("\n(( FINAL: ko có âm cuối ))", .{});
        syll.am_cuoi = ._none;
        syll.can_be_vietnamese = true;
        return syll; // DONE vì ko có phụ âm cuối
    }

    if (idx < bytes_len) { // Xác định ký tự thứ hai của âm cuối
        c1.parse(bytes, idx); // NẾU lấy ký tự tiếp theo
        idx += c1.len;
        if (idx < bytes_len) { // MÀ vẫn còn 1 dữ liệu
            // THÌ còn lại có nhiều hơn 2 ký tự
            syll.am_cuoi = ._none;
            syll.can_be_vietnamese = false;
            return syll; // DONE vì ko hợp lệ!
        }
    } else { // chỉ có 1 ký tự
        c1.byte0 = 0; // để phân tích đúng âm cuối có 1 ký tự
    }

    syll.am_cuoi = getFinal(c0.byte0, c1.byte0);

    // TODO: cần check can_be_vietnamese từ khâu initial và middle
    syll.can_be_vietnamese = (syll.am_cuoi != ._none); // VALIDATE âm cuối có hợp lệ
    return syll; // DONE
}
