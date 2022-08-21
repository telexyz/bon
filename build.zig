const std = @import("std");
// const ztracy = @import("libs/ztracy/build.zig");

fn setup(step: *std.build.LibExeObjStep) void {
    step.addCSourceFile("src/instructions.c", &[_][]const u8{ "-Wall", "-Wextra", "-Werror", "-O3" });
    step.linkLibC();
}

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    // const exe = b.addExecutable("am_dau", "src/am_dau.zig");
    // const exe = b.addExecutable("am_cuoi", "src/am_cuoi.zig");
    // const exe = b.addExecutable("am_tiet", "src/am_tiet.zig");
    const exe = b.addExecutable("char_stream", "src/char_stream.zig");
    // const exe = b.addExecutable("str_hash_count", "src/str_hash_count.zig");
    // const exe = b.addExecutable("turbo", "src/main.zig");

    // const ztracy_enable = b.option(bool, "ztracy-enable", "Enable Tracy profiler") orelse false;
    // const ztracy_options = ztracy.BuildOptionsStep.init(b, .{ .enable_ztracy = ztracy_enable });
    // const ztracy_pkg = ztracy.getPkg(&.{ztracy_options.getPkg()});
    // exe.addPackage(ztracy_pkg);
    // ztracy.link(exe, ztracy_options);

    exe.linkLibC();
    // setup(exe);
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/test.zig");
    setup(exe_tests);
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
