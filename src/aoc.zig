const std = @import("std");

const storage = @import("storage.zig");
const submit = @import("submit.zig");

const Solution = struct {
    part1: u64,
    part2: u64,
};

pub fn submitSolution(
    allocator: std.mem.Allocator,
    year: u16,
    day: u8,
    time_ns: u32,
    result: Solution,
) !void {
    var store = try storage.Storage.load(allocator);
    defer store.deinit();

    const record = try store.getOrCreateYear(year);
    const token = try std.fs.cwd().readFileAlloc(allocator, "TOKEN", 1024);
    defer allocator.free(token);

    // Try submitting each part if not already completed
    inline for (.{ 1, 2 }) |part| {
        if (!record.isComplete(day, @intCast(part))) {
            const answer = if (part == 1) result.part1 else result.part2;
            const outcome = try submit.submitPart(@intCast(part), answer, token, year, day);

            switch (outcome) {
                .correct => {
                    record.markComplete(day, @intCast(part));
                    record.updateTime(day, time_ns);
                    try std.io.getStdOut().writer().print("Part {d}: Correct! ⭐\n", .{part});
                    try store.save();
                },
                .incorrect => return error.IncorrectAnswer,
                .wait => return error.WaitRequired,
            }
        }
    }
}

pub fn getNextPuzzle(allocator: std.mem.Allocator, year: u16) !?struct { day: u8, part: u8 } {
    var store = try storage.Storage.load(allocator);
    defer store.deinit();

    if (store.records.items.len == 0) return .{ .day = 1, .part = 1 };

    for (store.records.items) |record| {
        if (record.year == year) {
            var day: u8 = 1;
            while (day <= 24) : (day += 1) {
                var part: u8 = 1;
                while (part <= 2) : (part += 1) {
                    if (!record.isComplete(day, part)) {
                        return .{ .day = day, .part = part };
                    }
                }
            }
        }
    }
    return null;
}
