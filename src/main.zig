const std = @import("std");
const build_options = @import("build_options");

const runner = @import("runner.zig");
const solution = @import("temp_solution.zig");

pub fn main() !void {
    try runner.run(build_options.year, build_options.day, solution, build_options.submit);
}
