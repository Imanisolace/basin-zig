const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // NEW: constant-time flag
    const constant_time = b.option(bool, "constant-time", "Enable constant-time mode. Slower but safe for secrets") orelse false;

    // SPEED: add flag for release builds
    const use_native = b.option(bool, "native", "Enable -march=native. Faster but not portable") orelse true;
    const use_avx2 = b.option(bool, "avx2", "Force enable AVX2. Ignored if native=false") orelse true;

    const basin_mod = b.addModule("basin", .{
        .root_source_file = b.path("src/basin.zig"),
        .target = target,
        .optimize = optimize,
    });
    basin_mod.addIncludePath(b.path("include"));

    // FIX: Build flags dynamically
    var c_flags = std.ArrayList([]const u8).init(b.allocator);
    defer c_flags.deinit();

    // Base flags
    c_flags.appendSlice(&.{ "-std=c99", "-Wall", "-Wextra", "-Werror", "-pedantic" }) catch @panic("OOM");

    // Speed flags. This is what fixes Blocker 2
    if (optimize == .ReleaseFast or optimize == .ReleaseSafe) {
        c_flags.append("-O3") catch @panic("OOM"); // was O2
        c_flags.append("-DNDEBUG") catch @panic("OOM"); // remove asserts
        c_flags.append("-ffast-math") catch @panic("OOM"); // new: faster fp math

        if (use_native) {
            c_flags.append("-march=native") catch @panic("OOM");
        } else if (use_avx2) {
            // Explicit AVX2 if not using native
            c_flags.append("-mavx2") catch @panic("OOM");
            c_flags.append("-mfma") catch @panic("OOM");
            c_flags.append("-D__AVX2__") catch @panic("OOM"); // so our #ifdef works
        }
    } else {
        c_flags.append("-O2") catch @panic("OOM"); // debug
        c_flags.append("-D__AVX2__") catch @panic("OOM"); // still define for debug builds
    }

    if (constant_time) {
        c_flags.append("-DCONSTANT_TIME=1") catch @panic("OOM");
    }

    const c_files = &.{ 
        "src/basin_config.c", 
        "src/basin_init.c", 
        "src/basin_poseidon.c", // <- your updated file with AVX2 inside
        "src/basin_parallel.c" 
    };

    // ========== Example exe ==========
    const exe = b.addExecutable(.{
        .name = "basin-example",
        .root_source_file = b.path("examples/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.addIncludePath(b.path("include"));
    exe.linkLibC();
    exe.linkSystemLibrary("pthread");
    exe.addCSourceFiles(.{ .files = c_files, .flags = c_flags.items });
    exe.root_module.addImport("basin", basin_mod);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| { run_cmd.addArgs(args); }
    const run_step = b.step("run", "Run the benchmark example");
    run_step.dependOn(&run_cmd.step);

    // ========== Tests ==========
    const tests = b.addTest(.{
        .root_source_file = b.path("tests/run.zig"),
        .target = target,
        .optimize = .ReleaseSafe, // Force ReleaseSafe for fair KAT + bench
    });
    tests.addIncludePath(b.path("include"));
    tests.linkLibC();
    tests.linkSystemLibrary("pthread");
    tests.addCSourceFiles(.{ .files = c_files, .flags = c_flags.items });
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

    // ========== Bench ==========
    const bench_cmd = b.addRunArtifact(exe);
    bench_cmd.step.dependOn(b.getInstallStep());
    bench_cmd.addArgs(&.{ "--bench", "--threads", "4" });
    const bench_step = b.step("bench", "Run ReleaseFast benchmark with 4 threads");
    bench_step.dependOn(&bench_cmd.step);
}