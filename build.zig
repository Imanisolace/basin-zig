const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const basin_mod = b.addModule("basin",.{
       .root_source_file = b.path("src/basin.zig"),
    });
    const merkle_mod = b.addModule("merkle",.{
       .root_source_file = b.path("src/merkle.zig"),
    });

    // 1. WASM Target for worker.js / browser
    const wasm_target = b.resolveTargetQuery(.{
       .cpu_arch =.wasm32,
       .os_tag =.wasi,
    });
    const wasm = b.addExecutable(.{
       .name = "basin",
       .root_source_file = b.path("src/wasm.zig"),
       .target = wasm_target,
       .optimize =.ReleaseSmall,
    });
    wasm.root_module.addImport("basin", basin_mod);
    wasm.root_module.addImport("merkle", merkle_mod);
    b.installArtifact(wasm);

    // 2. CLI Target for server.js to call
    const cli = b.addExecutable(.{
       .name = "basin-cli",
       .root_source_file = b.path("src/cli.zig"),
       .target = target,
       .optimize =.ReleaseSafe,
    });
    cli.root_module.addImport("basin", basin_mod);
    cli.root_module.addImport("merkle", merkle_mod);
    b.installArtifact(cli);

    // 3. Tests
    const test_step = b.step("test", "Run tests");
    const tests = b.addTest(.{
       .root_source_file = b.path("tests/run.zig"),
       .target = target,
       .optimize = optimize,
    });
    tests.root_module.addImport("basin", basin_mod);
    tests.root_module.addImport("merkle", merkle_mod);
    test_step.dependOn(&b.addRunArtifact(tests).step);
}