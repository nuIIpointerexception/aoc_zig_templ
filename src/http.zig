const std = @import("std");

pub fn getInput(alloc: std.mem.Allocator, comptime year: u32, comptime day: u32) ![]const u8 {
    var path_buf: [128]u8 = undefined;
    const input_path = try std.fmt.bufPrint(&path_buf, "src/{d}/{d}/input.txt", .{ year, day });

    return std.fs.cwd().readFileAlloc(alloc, input_path, std.math.maxInt(usize)) catch |err| switch (err) {
        error.FileNotFound => try fetchInput(alloc, year, day, input_path),
        else => return err,
    };
}

fn fetchInput(alloc: std.mem.Allocator, year: u32, day: u32, input_path: []const u8) ![]const u8 {
    var token_buf: [1024]u8 = undefined;
    const token = try std.fs.cwd().readFile("TOKEN", &token_buf);

    var client = std.http.Client{ .allocator = alloc };
    defer client.deinit();

    var url_buf: [128]u8 = undefined;
    const url = try std.fmt.bufPrint(&url_buf, "https://adventofcode.com/{d}/day/{d}/input", .{ year, day });

    var cookie_buf: [1024]u8 = undefined;
    const cookie = try std.fmt.bufPrint(&cookie_buf, "session={s}", .{token});

    var resp = std.ArrayList(u8).init(alloc);
    defer resp.deinit();

    const res = try client.fetch(.{
        .location = .{ .url = url },
        .method = .GET,
        .extra_headers = &[_]std.http.Header{.{ .name = "Cookie", .value = cookie }},
        .response_storage = .{ .dynamic = &resp },
    });
    if (res.status != .ok) return error.HttpError;

    try std.fs.cwd().makePath(input_path[0..std.mem.lastIndexOf(u8, input_path, "/").?]);
    try std.fs.cwd().writeFile(.{ .sub_path = input_path, .data = resp.items });
    return try std.fs.cwd().readFileAlloc(alloc, input_path, std.math.maxInt(usize));
}
