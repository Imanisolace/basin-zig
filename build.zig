const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const basin_mod = b.addModule("basin",.{
      .root_source_file = b.path("src/basin.zig"),
      .target = target,
      .optimize = optimize,
    });
    basin_mod.addIncludePath(b.path("include"));

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
      .files = &.{
            "src/basin_config.c",
            "src/basin_init.c", 
            "src/basin_poseidon.c",
            "src/basin_parallel.c",
        },
      .flags = &.{ "-std=c99", "-O2", "-Wall", "-Wextra", "-Werror", "-pedantic" },
    });
    exe.root_module.addImport("basin", basin_mod);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
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
      .files = &.{
            "src/basin_config.c",
            "src/basin_init.c", 
            "src/basin_poseidon.c",
            "src/basin_parallel.c",
        },
      .flags = &.{ "-std=c99", "-O2", "-Wall", "-Wextra", "-Werror", "-pedantic" },
    });
    tests.root_module.addImport("basin", basin_mod);

    const test_step = b.step("test", "Run correctness tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);

    // === ADD THIS: STEP 3/6 BENCH ===
    const bench_cmd = b.addRunArtifact(exe);
    bench_cmd.step.dependOn(b.getInstallStep());
    bench_cmd.addArgs(&.{ "--bench", "--threads", "4" });
    const bench_step = b.step("bench", "Run ReleaseFast benchmark with 4 threads");
    bench_step.dependOn(&bench_cmd.step);
}
