const std = @import("std");

// This is just a dummy zig wrapper so we have tests
// You can call your C functions here later with @cImport

test "basic sanity test" {
    try std.testing.expect(1 + 1 == 2);
}

test "string test" {
    const msg = "basin is building";
    try std.testing.expectEqualStrings("basin is building", msg);
}