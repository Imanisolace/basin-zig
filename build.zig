const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
       .name = "basin",
       .target = target,
       .optimize = optimize,
    });

    lib.addIncludePath(b.path("include"));

    // ALL 4 files that are actually in src/
    lib.addCSourceFiles(.{
       .files = &.{
            "src/basin_config.c",
            "src/basin_init.c",
            "src/basin_poseidon.c",
            "src/basin_parallel.c",
        },
       .flags = &.{ "-O2", "-Wall" },
    });

    b.installArtifact(lib);

    const tests = b.addTest(.{
       .root_source_file = b.path("src/basin.zig"),
       .target = target,
       .optimize = optimize,
    });
    tests.addIncludePath(b.path("include"));
    tests.linkLibrary(lib);
    tests.linkLibC();

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_tests.step);
}