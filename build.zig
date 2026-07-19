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
    lib.addIncludePath(b.path("include"));
    lib.linkLibC();
    lib.linkSystemLibrary("pthread");
    b.installArtifact(lib);

    // Tests
    const test_step = b.addTest(.{
        .root_source_file = b.path("src/basin.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_step.addIncludePath(b.path("include"));
    test_step.linkLibrary(lib);
    const run_test_step = b.addRunArtifact(test_step);
    b.step("test", "Run tests").dependOn(&run_test_step.step);

    // Example
    const exe = b.addExecutable(.{
        .name = "basin_example",
        .root_source_file = b.path("examples/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.addIncludePath(b.path("include"));
    exe.linkLibrary(lib);
    b.installArtifact(exe);
    const run_exe_step = b.addRunArtifact(exe);
    b.step("run", "Run example").dependOn(&run_exe_step.step);
}