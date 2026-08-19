const std = @import("std");

pub fn Int(comptime T: type) type {
    return struct {
        data: T,
        const Self = @This();
        const bits = @typeInfo(T).int.bits;
        const Wide = std.meta.Int(.unsigned, bits * 2);

        pub fn init(x: T) Self { return .{ .data = x }; }
        pub fn from(comptime U: type, x: U) Self { return .{ .data = @intCast(x) }; }
        pub fn to(self: Self, comptime U: type) U { return @intCast(self.data); }

        pub fn add(self: Self, other: Self) Self { return .{ .data = self.data +% other.data }; }
        pub fn sub(self: Self, other: Self) Self { return .{ .data = self.data -% other.data }; }

        // Wraps mod 2^bits. Fine for hashing/checksums. NOT safe for
        // modular arithmetic (finite fields, etc.) — use mulmod for that.
        pub fn mul(self: Self, other: Self) Self { return .{ .data = self.data *% other.data }; }

        // Widens to double-width before multiplying, so the full product
        // is preserved, then reduces by m. This is what any caller doing
        // field arithmetic should use instead of mul() + mod().
        pub fn mulmod(self: Self, other: Self, m: Self) Self {
            const a: Wide = self.data;
            const b: Wide = other.data;
            const prod: Wide = a * b;
            const mw: Wide = m.data;
            const reduced: T = @intCast(prod % mw);
            return .{ .data = reduced };
        }

        pub fn cmp(self: Self, other: Self) std.math.Order {
            if (self.data < other.data) return .lt;
            if (self.data > other.data) return .gt;
            return .eq;
        }
        pub fn mod(self: Self, m: Self) Self { return .{ .data = @rem(self.data, m.data) }; }
    };
}