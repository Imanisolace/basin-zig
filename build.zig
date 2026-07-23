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

    // 1. Example Binary
    const exe = b.addExecutable(.{
        .name = "basin-example",
        .root_source_file = b.path("examples/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("basin", basin_mod);
    b.installArtifact(exe);

    // 2. WASM Binary (Outputs directly to api/basin.wasm)
    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });
    const wasm = b.addExecutable(.{
        .name = "basin",
        .root_source_file = b.path("src/wasm.zig"),
        .target = wasm_target,
        .optimize = .ReleaseSmall,
    });
    wasm.rdynamic = true; 
    wasm.entry = .disabled;

    const wasm_install = b.addInstallArtifact(wasm, .{
        .dest_dir = .{ .override = .{ .custom = "api" } },
    });
    const wasm_step = b.step("wasm", "Build Wasm for API");
    wasm_step.dependOn(&wasm_install.step);

    // 3. Test Suite
    const tests = b.addTest(.{
        .name = "basin-test",
        .root_source_file = b.path("tests/run.zig"),
        .target = target,
        .optimize = optimize, // Respects user choice
    });
    tests.root_module.addImport("basin", basin_mod);

    const test_options = b.addOptions();
    test_options.addOption(bool, "skip_heavy", skip_heavy);
    tests.root_module.addImport("build_config", test_options.createModule());

    if (install_tests) b.installArtifact(tests);

    const run_tests = b.addRunArtifact(tests);
    b.step("test", "Run correctness tests").dependOn(&run_tests.step);

    const run_exe = b.addRunArtifact(exe);
    b.step("run", "Run the example").dependOn(&run_exe.step);
}