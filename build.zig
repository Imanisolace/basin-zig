const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    
    // NEW: constant-time flag
    const constant_time = b.option(bool, "constant-time", "Enable constant-time mode. Slower but safe for secrets") orelse false;

    const basin_mod = b.addModule("basin", .{
        .root_source_file = b.path("src/basin.zig"),
        .target = target,
        .optimize = optimize,
    });
    basin_mod.addIncludePath(b.path("include"));

    // NEW: add -DCONSTANT_TIME=1 if flag is on
    const c_flags = if (constant_time) 
        &.{ "-std=c99", "-O2", "-DCONSTANT_TIME=1", "-Wall", "-Wextra", "-Werror", "-pedantic" }
    else 
        &.{ "-std=c99", "-O2", "-Wall", "-Wextra", "-Werror", "-pedantic" };

    const exe = b.addExecutable(.{
        .name = "basin-example",
        .root_source_file = b.path("examples/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.addIncludePath(b.path("include"));
    exe.linkLibC();
    exe.linkSystemLibrary("pthread");
    exe.addCSourceFiles(.{
        .files = &.{ "src/basin_config.c", "src/basin_init.c", "src/basin_poseidon.c", "src/basin_parallel.c" },
        .flags = c_flags, // USE c_flags
    });
    exe.root_module.addImport("basin", basin_mod);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| { run_cmd.addArgs(args); }
    const run_step = b.step("run", "Run the benchmark example");
    run_step.dependOn(&run_cmd.step);

    const tests = b.addTest(.{
        .root_source_file = b.path("tests/run.zig"),
        .target = target,
        .optimize = optimize,
    });
    tests.addIncludePath(b.path("include"));
    tests.linkLibC();
    tests.linkSystemLibrary("pthread");
    tests.addCSourceFiles(.{
        .files = &.{ "src/basin_config.c", "src/basin_init.c", "src/basin_poseidon.c", "src/basin_parallel.c" },
        .flags = c_flags, // USE c_flags
    });
    tests.root_module.addImport("basin", basin_mod);

    const skip_heavy = b.option(bool, "skip-heavy", "Skip CPU-intensive/AVX tests") orelse false;
    const build_config_file = b.addWriteFile("build_config.zig", b.fmt("pub const skip_heavy = {};", .{skip_heavy}));
    tests.root_module.addAnonymousImport("build_config", .{
        .root_source_file = build_config_file.getDirectory().path(b, "build_config.zig"),
    });

    const install_tests = b.option(bool, "install-tests", "Install the test binary to zig-out/bin") orelse false;
    if (install_tests) {
        const install_art = b.addInstallArtifact(tests, .{ .dest_sub_path = "basin-test" });
        b.getInstallStep().dependOn(&install_art.step);
    }

    const test_step = b.step("test", "Run correctness tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);

    const bench_cmd = b.addRunArtifact(exe);
    bench_cmd.step.dependOn(b.getInstallStep());
    bench_cmd.addArgs(&.{ "--bench", "--threads", "4" });
    const bench_step = b.step("bench", "Run ReleaseFast benchmark with 4 threads");
    bench_step.dependOn(&bench_cmd.step);
}