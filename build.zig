const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const constant_time = b.option(bool, "constant-time", "Enable constant-time mode. Slower but safe for secrets") orelse false;
    const use_native = b.option(bool, "native", "Enable -march=native. Faster but not portable") orelse false;

    const basin_mod = b.addModule("basin", .{
        .root_source_file = b.path("src/basin.zig"),
        .target = target,
        .optimize = optimize,
    });
    basin_mod.addIncludePath(b.path("include"));

    var c_flags = std.ArrayList([]const u8).init(b.allocator);
    defer c_flags.deinit();

    // Base flags
    c_flags.appendSlice(&.{ "-std=c11", "-Wall", "-Wextra", "-Werror", "-pedantic" }) catch @panic("OOM");

    if (optimize == .ReleaseFast or optimize == .ReleaseSafe) {
        c_flags.append("-O3") catch @panic("OOM");
        c_flags.append("-DNDEBUG") catch @panic("OOM");
        if (use_native) {
            c_flags.append("-march=native") catch @panic("OOM");
        }
    } else {
        c_flags.append("-O2") catch @panic("OOM");
    }

    if (constant_time) {
        c_flags.append("-DCONSTANT_TIME=1") catch @panic("OOM");
    }

    const c_files = &.{
        "src/basin_config.c",
        "src/basin_init.c",
        "src/basin_poseidon.c",
        "src/basin_parallel.c",
    };

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

    const tests = b.addTest(.{
        .root_source_file = b.path("tests/run.zig"),
        .target = target,
        .optimize = .ReleaseSafe,
    });
    tests.addIncludePath(b.path("include"));
    tests.linkLibC();
    tests.linkSystemLibrary("pthread");
    tests.addCSourceFiles(.{ .files = c_files, .flags = c_flags.items });
    tests.root_module.addImport("basin", basin_mod);

    const skip_heavy = b.option(bool, "skip-heavy", "Skip CPU-intensive tests") orelse false;
    const build_config_file = b.addWriteFile("build_config.zig", b.fmt("pub const skip_heavy = {};", .{skip_heavy}));
    tests.root_module.addAnonymousImport("build_config", .{
        .root_source_file = build_config_file.getDirectory().path(b, "build_config.zig"),
    });

    const test_step = b.step("test", "Run correctness tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
}