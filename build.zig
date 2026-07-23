const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const skip_heavy = b.option(bool, "skip-heavy", "Skip CPU-intensive tests") orelse false;
    const install_tests = b.option(bool, "install-tests", "Install test binary to zig-out/bin") orelse false;

    // Core Basin module
    const basin_mod = b.addModule("basin", .{
        .root_source_file = b.path("src/basin.zig"),
        .target = target,
        .optimize = optimize,
    });

    // 1. Example Binary - No C, No linkLibC
    const exe = b.addExecutable(.{
        .name = "basin-example",
        .root_source_file = b.path("examples/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("basin", basin_mod);
    b.installArtifact(exe);

    // 2. Test Suite - No C
    const tests = b.addTest(.{
        .name = "basin-test",
        .root_source_file = b.path("tests/run.zig"),
        .target = target,
        .optimize = .ReleaseSafe,
    });
    tests.root_module.addImport("basin", basin_mod);

    // 0.14 file generation for skip_heavy flag
    const wf = b.addWriteFiles();
    const config_path = wf.add("build_config.zig", b.fmt("pub const skip_heavy = {};\n", .{skip_heavy}));
    
    tests.step.dependOn(&wf.step); // build order fix

    tests.root_module.addAnonymousImport("build_config", .{
        .root_source_file = config_path,
    });

    if (install_tests) b.installArtifact(tests);

    const run_tests = b.addRunArtifact(tests);
    b.step("test", "Run correctness tests").dependOn(&run_tests.step);

    const run_exe = b.addRunArtifact(exe);
    b.step("run", "Run the example").dependOn(&run_exe.step);
}