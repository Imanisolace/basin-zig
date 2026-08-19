const std = @import("std");
const merkle = @import("merkle");
const basin = @import("basin");

fn toHex(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    const hex = "0123456789abcdef";
    const out = try allocator.alloc(u8, bytes.len * 2);
    for (bytes, 0..) |b, i| {
        out[i * 2] = hex[b >> 4];
        out[i * 2 + 1] = hex[b & 0xF];
    }
    return out;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 4 or !std.mem.eql(u8, args[1], "prove")) {
        std.debug.print("Usage: basin-cli prove \"leaf1,leaf2,leaf3\" index\n", .{});
        std.process.exit(1);
    }

    var list = std.ArrayList([]const u8).init(allocator);
    defer list.deinit();
    var it = std.mem.splitScalar(u8, args[2], ',');
    while (it.next()) |leaf| {
        if (leaf.len > 0) try list.append(leaf);
    }
    const leaves = list.items;
    const index = try std.fmt.parseInt(usize, args[3], 10);

    const root = try merkle.buildMerkleRoot(leaves, allocator);
    defer allocator.free(root);

    const proof = try merkle.generateProof(leaves, index, allocator);
    defer allocator.free(proof); // ProofStep is a value type now — one free, not per-element

    const root_hex = try toHex(allocator, root);
    defer allocator.free(root_hex);

    std.debug.print("{{\"root\":\"0x{s}\",\"proof\":[", .{root_hex});
    for (proof, 0..) |step, i| {
        if (i > 0) std.debug.print(",", .{});
        if (step.sibling) |sib| {
            const sib_hex = try toHex(allocator, &sib);
            defer allocator.free(sib_hex);
            std.debug.print("{{\"sibling\":\"0x{s}\",\"is_right\":{}}}", .{ sib_hex, step.is_right });
        } else {
            std.debug.print("{{\"sibling\":null,\"is_right\":false}}", .{});
        }
    }
    std.debug.print("]}}\n", .{});
}