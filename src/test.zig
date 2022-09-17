test "all" {
    _ = @import("instructions.zig");
    _ = @import("syllable.zig");
    _ = @import("syllable_count.zig");
    _ = @import("ky_tu.zig");
    _ = @import("am_dau.zig");
    _ = @import("am_giua.zig");
    _ = @import("am_cuoi.zig");
    _ = @import("am_tiet_parse.zig");
    _ = @import("char_stream.zig");

    _ = @import("lookup_tables.zig");
    _ = @import("hash_count_str.zig");
    _ = @import("am_tiet_test.zig");
    _ = @import("byte_pair_encoding.zig");
}
