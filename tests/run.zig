const std = @import("std");
const basin = @import("basin");
const merkle = @import("merkle"); // imports src/merkle.zig via build.zig
const build_config = @import("build_config");
const prng = std.Random.DefaultPrng;

// THIS RUNS all tests inside tests/merkle_test.zig
test {
    _ = @import("merkle_test.zig");
}

fn hashToHex(input: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const hash_bytes = try basin.poseidonHash(input, allocator);
    defer allocator.free(hash_bytes);
    return try basin.toHex(hash_bytes, allocator);
}

test "HASH: empty input fails" {
    try std.testing.expectError(
        basin.BasinError.EmptyInput,
        basin.poseidonHash("", std.testing.allocator),
    );
}

test "HASH: returns 32 bytes" {
    const hash = try basin.poseidonHash("test", std.testing.allocator);
    defer std.testing.allocator.free(hash);
    try std.testing.expectEqual(@as(usize, 32), hash.len);
}

test "HASH: streaming matches one-shot" {
    const allocator = std.testing.allocator;
    const data = try allocator.alloc(u8, 10000);
    defer allocator.free(data);
    @memset(data, 'x');

    const h1 = try basin.poseidonHash(data, allocator);
    defer allocator.free(h1);

    var hasher = basin.Hasher.init();
    hasher.update(data[0..5000]);
    hasher.update(data[5000..]);

    var h2: [32]u8 = undefined;
    hasher.final(&h2);

    try std.testing.expectEqualSlices(u8, h1, &h2);
}

test "TOHEX: roundtrip" {
    const data = [_]u8{ 0xDE, 0xAD, 0xBE, 0xEF };
    const hex = try basin.toHex(&data, std.testing.allocator);
    defer std.testing.allocator.free(hex);
    try std.testing.expectEqualStrings("deadbeef", hex);
}

test "PROP: binary data with nulls is handled" {
    const data = &[_]u8{ 0, 1, 2, 255, 0, 0, 42 };
    const hash = try basin.poseidonHash(data, std.testing.allocator);
    defer std.testing.allocator.free(hash);
    try std.testing.expectEqual(@as(usize, 32), hash.len);
}

test "EDGE: block boundaries" {
    const allocator = std.testing.allocator;
    const lengths = [_]usize{ 15, 16, 17, 32, 1024 };
    for (lengths) |len| {
        const data = try allocator.alloc(u8, len);
        defer allocator.free(data);
        @memset(data, 'a');
        const hash = try basin.poseidonHash(data, allocator);
        defer allocator.free(hash);
        try std.testing.expectEqual(@as(usize, 32), hash.len);
    }
}

test "FUZZ: random bytes dont crash" {
    var rng = prng.init(0x1234);
    const allocator = std.testing.allocator;
    var buf: [256]u8 = undefined;
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const len = rng.random().intRangeAtMost(usize, 0, buf.len);
        rng.random().bytes(buf[0..len]);
        const hash = basin.poseidonHash(buf[0..len], allocator) catch continue;
        defer allocator.free(hash);
        try std.testing.expectEqual(@as(usize, 32), hash.len);
    }
}

test "BENCH: speed" {
    if (build_config.skip_heavy) return error.SkipZigTest;
    const allocator = std.testing.allocator;
    const data = try allocator.alloc(u8, 1 * 1024 * 1024);
    defer allocator.free(data);
    std.crypto.random.bytes(data);

    var timer = try std.time.Timer.start();
    const hash = try basin.poseidonHash(data, allocator);
    defer allocator.free(hash);
    const ns = timer.read();

    const mb_s = 1.0 / (@as(f64, @floatFromInt(ns)) / 1e9);
    std.debug.print("\nbasin: {d:.2} MB/s\n", .{mb_s});
}

// ========== BN254 + MERKLE TESTS ==========

test "SANITY: P-1 constant matches across derivations" {
    // Confirms the decimal-literal P-1 (used below) and the hex-derived
    // P-1 (used in merkle_test.zig's Fr.mul test) are actually the same
    // number, byte for byte. If this fails, one of the two derivations
    // has a real error, and it's important to know that before trusting
    // either test that depends on it.
    const decimal_bytes = std.mem.toBytes(std.mem.nativeToLittle(
        u256,
        21888242871839275222246405745257275088548364400416034343698204186575808495616,
    ));
    const hex_derived_bytes = [32]u8{
        0x00, 0x00, 0x00, 0xf0, 0x93, 0xf5, 0xe1, 0x43,
        0x91, 0x70, 0xb9, 0x79, 0x48, 0xe8, 0x33, 0x28,
        0x5d, 0x58, 0x81, 0x81, 0xb6, 0x45, 0x50, 0xb8,
        0x29, 0xa0, 0x31, 0xe1, 0x72, 0x4e, 0x64, 0x30,
    };
    try std.testing.expectEqualSlices(u8, &decimal_bytes, &hex_derived_bytes);
}

test "FR: BN254 add matches solidity math" {
    const Fr = merkle.Fr;

    const one_bytes: [32]u8 = [_]u8{1} ++ ([_]u8{0} ** 31);
    const two_bytes: [32]u8 = [_]u8{2} ++ ([_]u8{0} ** 31);
    const three_bytes: [32]u8 = [_]u8{3} ++ ([_]u8{0} ** 31);

    const one = Fr.fromBytes(one_bytes);
    const two = Fr.fromBytes(two_bytes);
    const expected = Fr.fromBytes(three_bytes);

    const three = one.add(two);
    try std.testing.expect(three.eq(expected));
}

test "FR: BN254 add wraps at prime" {
    const Fr = merkle.Fr;
    const one_bytes: [32]u8 = [_]u8{1} ++ ([_]u8{0} ** 31);
    const one = Fr.fromBytes(one_bytes);

    // P - 1 for BN254, via nativeToLittle on the u256 directly — this
    // avoids hand-encoding a byte array and the byte-order mistakes that
    // come with it. Cross-checked against an independently-derived hex
    // version in the sanity test above.
    const p_minus_1_val: u256 = 21888242871839275222246405745257275088548364400416034343698204186575808495616;
    const p_minus_1 = Fr.fromBytes(std.mem.toBytes(std.mem.nativeToLittle(u256, p_minus_1_val)));

    const result = p_minus_1.add(one); // should wrap to 0
    try std.testing.expect(result.eq(Fr.zero));
}

test "MERKLE: root with real Fr math" {
    const allocator = std.testing.allocator;
    const leaves = [_][]const u8{ "leaf1", "leaf2", "leaf3", "leaf4" };

    const root = try merkle.buildMerkleRoot(&leaves, allocator);
    defer allocator.free(root);

    try std.testing.expectEqual(@as(usize, 32), root.len);

    // Regression pin: once you've independently verified the correct root
    // for these exact leaves, hardcode its hex here so any future change
    // that silently alters output gets caught immediately.
    // const expected_hex = "...";
    // const hex = try basin.toHex(root, allocator);
    // defer allocator.free(hex);
    // try std.testing.expectEqualStrings(expected_hex, hex);
}