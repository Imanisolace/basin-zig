const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 1. Build the static library: libbasin.a
    const lib = b.addStaticLibrary(.{
        .name = "basin",
        .target = target,
        .optimize = optimize,
    });
    lib.addCSourceFiles(.{
        .files = &.{
            "src/basin.c", // <-- change this to your actual .c files
        },
        .flags = &.{},
    });
    lib.addIncludePath(b.path("include"));
    lib.linkLibC();
    b.installArtifact(lib);

    // 2. Build the example executable
    const exe = b.addExecutable(.{
        .name = "basin_example",
        .root_source_file = b.path("examples/main.zig"), // Only listed ONCE
        .target = target,
        .optimize = optimize,
    });
    exe.addIncludePath(b.path("include"));
    exe.linkLibrary(lib); // Link our static lib
    exe.linkLibC();
    b.installArtifact(exe);

    // 3. Make `zig build run` work
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the example");
    run_step.dependOn(&run_cmd.step);

    // 4. Make `zig build test` work
    const test_step = b.step("test", "Run tests");
    const lib_tests = b.addTest(.{
        .root_source_file = b.path("src/basin.zig"), // <-- change if you have tests
        .target = target,
        .optimize = optimize,
    });
    test_step.dependOn(&b.addRunArtifact(lib_tests).step);
}