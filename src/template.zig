const std = @import("std");

pub fn main(input: []const u8) !struct { part1: u64, part2: u64, time: f64 } {
    var start = try std.time.Timer.start();
    _ = input; // autofix

    // start here!

    const time = @as(f64, @floatFromInt(start.lap())) / std.time.ns_per_us;
    return .{ .part1 = 0, .part2 = 0, .time = time };
}

test "day x" {
    const input = "";
    const result = try main(input);
    try std.testing.expectEqual(0, result.part1);
    try std.testing.expectEqual(0, result.part2);
}
