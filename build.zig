const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build the C library
    const basin_lib = b.addStaticLibrary(.{
        .name = "basin",
        .target = target,
        .optimize = optimize,
    });

    basin_lib.addIncludePath(b.path("include"));
    basin_lib.addCSourceFiles(.{
        .files = &.{
            "src/basin_init.c",
            "src/basin_config.c", 
            "src/basin_poseidon.c",
            "src/basin_parallel.c",
        },
        .flags = &.{ "-O3", "-Wall", "-std=c11" },
    });
    basin_lib.linkLibC();
    b.installArtifact(basin_lib);

    // Example executable
    const example = b.addExecutable(.{
        .name = "basin_example",
        .target = target,
        .optimize = optimize,
    });
    example.addIncludePath(b.path("include"));
    example.addCSourceFile(.{ .file = b.path("examples/main.zig") });
    example.linkLibrary(basin_lib);
    example.linkLibC();
    b.installArtifact(example);

    // Test runner
    const tests = b.addExecutable(.{
        .name = "basin_tests",
        .root_source_file = b.path("tests/run.zig"),
        .target = target,
        .optimize = optimize,
    });
    tests.addIncludePath(b.path("include"));
    tests.linkLibrary(basin_lib);
    tests.linkLibC();
    
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_tests.step);
}
