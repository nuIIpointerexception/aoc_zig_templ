const std = @import("std");
const sdout = std.io.getStdOut;

const storage = @import("storage.zig");

const Outcome = enum { correct, incorrect, wait, wrong_level };

pub fn submitSolution(
    allocator: std.mem.Allocator,
    year: u32,
    day: u32,
    time_ns: u32,
    result: anytype,
) !void {
    var store = try storage.Storage.load(allocator);
    defer store.deinit();

    const record = try store.getOrCreateYear(@intCast(year));
    const token = try std.fs.cwd().readFileAlloc(allocator, "TOKEN", 1024);
    defer allocator.free(token);

    inline for (.{ 1, 2 }) |part| {
        if (store.isPartCompleted(year, day, @intCast(part))) {
            try sdout().writer().print("Part {d}: Already completed! ⭐\n", .{part});
            record.markCompleted(@intCast(day), @intCast(part));
            record.updateTime(@intCast(day), time_ns);
            try store.save();
        } else {
            const answer = if (part == 1) result.part1 else result.part2;
            const outcome = try submitPart(@intCast(part), answer, token, @intCast(year), @intCast(day));

            switch (outcome) {
                .correct => {
                    record.markCompleted(@intCast(day), @intCast(part));
                    record.updateTime(@intCast(day), time_ns);
                    try sdout().writer().print("Part {d}: Correct! ⭐\n", .{part});
                    try store.save();
                },
                .incorrect => {
                    try sdout().writer().print("Part {d}: Incorrect answer\n", .{part});
                    return error.IncorrectAnswer;
                },
                .wait => {
                    try sdout().writer().print("Part {d}: Please wait before submitting again\n", .{part});
                    return error.WaitRequired;
                },
                .wrong_level => {
                    try sdout().writer().print("Part {d}: Already completed this part\n", .{part});
                    record.markCompleted(@intCast(day), @intCast(part));
                    record.updateTime(@intCast(day), time_ns);
                    try store.save();
                },
            }
        }
    }
}

fn submitPart(part: u8, answer: u64, token: []const u8, year: u16, day: u8) !Outcome {
    var client = std.http.Client{ .allocator = std.heap.page_allocator };
    defer client.deinit();

    var resp = std.ArrayList(u8).init(std.heap.page_allocator);
    defer resp.deinit();

    const res = try client.fetch(.{
        .location = .{
            .url = try std.fmt.allocPrint(
                std.heap.page_allocator,
                "https://adventofcode.com/{d}/day/{d}/answer",
                .{ year, day },
            ),
        },
        .method = .POST,
        .extra_headers = &[_]std.http.Header{
            .{ .name = "Cookie", .value = try std.fmt.allocPrint(
                std.heap.page_allocator,
                "session={s}",
                .{token},
            ) },
            .{ .name = "Content-Type", .value = "application/x-www-form-urlencoded" },
        },
        .payload = try std.fmt.allocPrint(
            std.heap.page_allocator,
            "level={d}&answer={d}",
            .{ part, answer },
        ),
        .response_storage = .{ .dynamic = &resp },
    });

    if (res.status != .ok) return error.HttpError;

    const html = resp.items;
    if (std.mem.indexOf(u8, html, "That's the right answer") != null) {
        return .correct;
    } else if (std.mem.indexOf(u8, html, "That's not the right answer") != null) {
        return .incorrect;
    } else if (std.mem.indexOf(u8, html, "You gave an answer too recently") != null) {
        return .wait;
    } else if (std.mem.indexOf(u8, html, "You don't seem to be solving the right level") != null) {
        return .wrong_level;
    }
    return error.UnknownResponse;
}
