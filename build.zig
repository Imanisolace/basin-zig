const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 1. Build the static library: libbasin.a from your 4 C files
    const lib = b.addStaticLibrary(.{
        .name = "basin",
        .target = target,
        .optimize = optimize,
    });
    lib.addCSourceFiles(.{
        .files = &.{
            "src/basin_config.c",
            "src/basin_init.c", 
            "src/basin_parallel.c",
            "src/basin_poseidon.c",
        },
        .flags = &.{},
    });
    lib.addIncludePath(b.path("include"));
    lib.linkLibC();
    b.installArtifact(lib);

    // 2. Build the example executable
    const exe = b.addExecutable(.{
        .name = "basin_example",
        .root_source_file = b.path("examples/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.addIncludePath(b.path("include"));
    exe.linkLibrary(lib); // Link libbasin.a
    exe.linkLibC();
    b.installArtifact(exe);

    // 3. zig build run
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the example");
    run_step.dependOn(&run_cmd.step);
}