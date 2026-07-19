const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "basin",
        .target = target,
        .optimize = optimize,
    });
    lib.addCSourceFiles(.{
        .files = &.{
            "src/basin_config.c",
            "src/basin_init.c", 
            "src/basin_poseidon.c",
            "src/basin_parallel.c",
        },
    });
    lib.addIncludePath(b.path("include")); // <-- FIXED
    lib.linkLibC();
    lib.linkSystemLibrary("pthread");
    b.installArtifact(lib);

    // Tests
    const tests = b.addTest(.{
        .root_source_file = b.path("src/basin.zig"), // <-- FIXED
        .target = target,
        .optimize = optimize,
    });
    tests.addIncludePath(b.path("include")); // <-- FIXED
    tests.linkLibrary(lib);
    const run_tests = b.addRunArtifact(tests);
    b.step("test", "Run tests").dependOn(&run_tests.step);

    // Example
    const example = b.addExecutable(.{
        .name = "basin_example",
        .root_source_file = b.path("examples/main.zig"), // <-- FIXED
        .target = target,
        .optimize = optimize,
    });
    example.addIncludePath(b.path("include")); // <-- FIXED
    example.linkLibrary(lib);
    b.installArtifact(example);
    const run_example = b.addRunArtifact(example);
    b.step("run", "Run example").dependOn(&run_example.step);
}