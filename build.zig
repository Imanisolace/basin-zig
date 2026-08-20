const std = @import("std");

pub fn build(b: *std.Build) void {
    const basin_mod = b.addModule("basin", .{
        .root_source_file = b.path("src/basin.zig"),
    });

    // freestanding, not wasi: worker.js only supplies an `env` import
    // object (memory) at instantiation — no wasi_snapshot_preview1.
    // A wasi-targeted build risks a LinkError at runtime the moment any
    // std function pulls in a WASI import, even if today's code paths
    // happen not to trigger one.
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
    wasm.root_module.addImport("basin", basin_mod);

    wasm.rdynamic = true;   // required so `export fn` symbols are visible to JS
    wasm.root_module.strip = false;
    wasm.entry = .disabled; // freestanding + disabled entry: no _start, no WASI runtime expected

    const install_wasm = b.addInstallArtifact(wasm, .{});
    b.getInstallStep().dependOn(&install_wasm.step);

    // worker.js expects basin.wasm sitting next to it in src/, not
    // inside zig-out/bin/ where addInstallArtifact places it by default.
    // Copy the built artifact to the exact path worker.js reads from.
    const copy_wasm = b.addInstallFileWithDir(
        wasm.getEmittedBin(),
        .{ .custom = "../src" },
        "basin.wasm",
    );
    copy_wasm.step.dependOn(&install_wasm.step);
    b.getInstallStep().dependOn(&copy_wasm.step);

    const test_step = b.step("test", "Build wasm for CI");
    test_step.dependOn(b.getInstallStep());
}