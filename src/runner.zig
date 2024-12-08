const std = @import("std");

const http = @import("http.zig");
const storage = @import("storage.zig");
const submit = @import("submit.zig");

pub fn run(comptime year: u32, comptime day: u32, comptime solution: type, should_submit: bool) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var store = try storage.Storage.load(alloc);
    defer store.deinit();

    const input = try http.getInput(alloc, year, day);
    defer alloc.free(input);

    const result = try solution.main(input);
    std.debug.print("Time: {d:.3} us\n", .{result.time});
    std.debug.print("Solutions:\n- Part 1: {}\n- Part 2: {}\n", .{ result.part1, result.part2 });

    if (should_submit) {
        if (store.isDayCompleted(year, day)) {
            std.debug.print("Day {d} already completed! ⭐⭐\n", .{day});
            return;
        }
        try submit.submitSolution(alloc, year, day, @as(u32, @intFromFloat(result.time)), result);
    }
}
