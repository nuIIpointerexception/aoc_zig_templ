const std = @import("std");

const YearRecord = struct {
    year: u16,
    completion_bits: u48,
    best_times: [24]u32,

    fn getBitIndex(day: u8, part: u8) u6 {
        return @as(u6, @intCast((day - 1) * 2 + (part - 1)));
    }

    pub fn isCompleted(self: YearRecord, day: u8, part: u8) bool {
        return (self.completion_bits & (@as(u48, 1) << getBitIndex(day, part))) != 0;
    }

    pub fn isDayCompleted(self: YearRecord, day: u8) bool {
        const bit_index = (day - 1) * 2;
        const mask = @as(u48, 0b11) << @intCast(bit_index);
        return (self.completion_bits & mask) == mask;
    }

    pub fn markCompleted(self: *YearRecord, day: u8, part: u8) void {
        self.completion_bits |= @as(u48, 1) << getBitIndex(day, part);
    }

    pub fn updateTime(self: *YearRecord, day: u8, time_ns: u32) void {
        if (time_ns < self.best_times[day - 1] or self.best_times[day - 1] == 0) {
            self.best_times[day - 1] = time_ns;
        }
    }
};

pub const Storage = struct {
    records: std.ArrayList(YearRecord),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Storage {
        return .{
            .records = std.ArrayList(YearRecord).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Storage) void {
        self.records.deinit();
    }

    pub fn load(allocator: std.mem.Allocator) !Storage {
        var storage = Storage.init(allocator);
        errdefer storage.deinit();

        const file = std.fs.cwd().openFile("aoc.bin", .{}) catch {
            return storage;
        };
        defer file.close();

        var reader = file.reader();
        while (true) {
            const year = reader.readInt(u16, .little) catch |err| switch (err) {
                error.EndOfStream => break,
                else => |e| return e,
            };

            var best_times: [24]u32 = undefined;
            try storage.records.append(.{
                .year = year,
                .completion_bits = try reader.readInt(u48, .little),
                .best_times = blk: {
                    for (&best_times) |*time| {
                        time.* = try reader.readInt(u32, .little);
                    }
                    break :blk best_times;
                },
            });
        }
        return storage;
    }

    pub fn save(self: Storage) !void {
        const file = try std.fs.cwd().createFile("aoc.bin", .{});
        defer file.close();

        var writer = file.writer();
        for (self.records.items) |record| {
            try writer.writeInt(u16, record.year, .little);
            try writer.writeInt(u48, record.completion_bits, .little);
            try writer.writeAll(std.mem.sliceAsBytes(&record.best_times));
        }
    }

    pub fn getOrCreateYear(self: *Storage, year: u32) !*YearRecord {
        for (self.records.items) |*record| {
            if (record.year == @as(u16, @intCast(year))) return record;
        }
        try self.records.append(.{
            .year = @as(u16, @intCast(year)),
            .completion_bits = 0,
            .best_times = [_]u32{0} ** 24,
        });
        return &self.records.items[self.records.items.len - 1];
    }

    pub fn isDayCompleted(self: Storage, year: u32, day: u32) bool {
        for (self.records.items) |record| {
            if (record.year == @as(u16, @intCast(year))) {
                return record.isDayCompleted(@as(u8, @intCast(day)));
            }
        }
        return false;
    }

    pub fn isPartCompleted(self: Storage, year: u32, day: u32, part: u8) bool {
        for (self.records.items) |record| {
            if (record.year == @as(u16, @intCast(year))) {
                return record.isCompleted(@as(u8, @intCast(day)), part);
            }
        }
        return false;
    }
};
