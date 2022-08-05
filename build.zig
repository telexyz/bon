const std = @import("std");

fn setup(step: *std.build.LibExeObjStep, mode: std.builtin.Mode, target: anytype) void {
    step.addCSourceFile("src/simd.c", &[_][]const u8{ "-Wall", "-Wextra", "-Werror", "-O3" });
    step.setTarget(target);
    step.linkLibC();
    step.setBuildMode(mode);
}

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    // const exe = b.addExecutable("simd_byte_lookup", "src/simd_byte_lookup_algorithm.zig");
    // const exe = b.addExecutable("simd_byte_lookup", "src/simd_byte_lookup_deploy.zig");
    // const exe = b.addExecutable("am_dau", "src/am_dau.zig");
    // const exe = b.addExecutable("am_cuoi", "src/am_cuoi.zig");
    const exe = b.addExecutable("am_tiet", "src/am_tiet.zig");
    // const exe = b.addExecutable("char_stream", "src/char_stream.zig");
    setup(exe, mode, target);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args|
        run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/simd.zig");
    setup(exe_tests, mode, target);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
