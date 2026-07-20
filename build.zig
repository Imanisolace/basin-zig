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
      .flags = &.{ "-std=c99", "-O2" },
    });
    exe.root_module.addImport("basin", basin_mod);
    b.installArtifact(exe);

    // RUN STEP with args
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| { // <-- this is the key line
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the benchmark example");
    run_step.dependOn(&run_cmd.step);

    // TEST STEP
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
      .flags = &.{ "-std=c99", "-O2" },
    });
    tests.root_module.addImport("basin", basin_mod);

    const test_step = b.step("test", "Run correctness tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
}