const std = @import("std");

pub fn build(b: *std.Build) void {
    const basin_mod = b.addModule("basin", .{
        .root_source_file = b.path("src/basin.zig"),
    });

    // WASM Target for worker.js
    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .wasi,
    });

    const wasm = b.addExecutable(.{
        .name = "basin",
        .root_source_file = b.path("src/wasm.zig"),
        .target = wasm_target,
        .optimize = .ReleaseSmall,
    });
    wasm.root_module.addImport("basin", basin_mod);

    // Zig 0.14 fix: keep all exports so JS can call them
    // rdynamic = keep all exported symbols
    // strip = false = don't remove debug info/exports
    // single_threaded = required for wasi
    wasm.rdynamic = true;
    wasm.strip = false;
    wasm.single_threaded = true;

    b.installArtifact(wasm);
}