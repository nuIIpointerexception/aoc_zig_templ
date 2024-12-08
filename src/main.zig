const std = @import("std");
const build_options = @import("build_options");

const http = @import("http.zig");
const solution = @import("temp_solution.zig");
const storage = @import("storage.zig");
const submit = @import("submit.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var store = try storage.Storage.load(alloc);
    defer store.deinit();

    const input = try http.getInput(alloc, build_options.year, build_options.day);
    defer alloc.free(input);

    const result = try solution.main(input);
    std.debug.print("Time: {d:.3} us\n", .{result.time});
    std.debug.print("Solutions:\n- Part 1: {}\n- Part 2: {}\n", .{ result.part1, result.part2 });

    if (build_options.submit) {
        if (store.isDayCompleted(build_options.year, build_options.day)) {
            std.debug.print("Day {d} already completed! ⭐⭐\n", .{build_options.day});
            return;
        }
        try submit.submitSolution(alloc, build_options.year, build_options.day, @as(u32, @intFromFloat(result.time)), result);
    }
}
