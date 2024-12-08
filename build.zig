const std = @import("std");
const builtin = @import("builtin");

const DateTime = @import("src/util.zig").DateTime;

comptime {
    const required_zig = "0.14.0-dev";
    const current_zig = builtin.zig_version;
    const min_zig = std.SemanticVersion.parse(required_zig) catch unreachable;
    if (current_zig.order(min_zig) == .lt) {
        const error_message =
            \\Sorry, it looks like your version of zig is too old. :-(
            \\
            \\aoc_zig requires development build {}
            \\
            \\Please download a development ("master") build from
            \\
            \\https://ziglang.org/download/
            \\
            \\
        ;
        @compileError(std.fmt.comptimePrint(error_message, .{min_zig}));
    }
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const date = DateTime.now();
    const year = b.option(u16, "year", "year") orelse date.year;
    const current_day = date.day;

    if (current_day >= 1 and current_day <= 25) {
        const setup = createSetupStep(b, year, current_day);

        const base_run = createRunStep(b, year, current_day, target, optimize, false);
        base_run.step.dependOn(setup);
        b.step("run", "Run current day").dependOn(&base_run.step);

        const base_test = b.addTest(.{
            .root_source_file = b.path(b.fmt("src/{d}/{d}/solution.zig", .{ year, current_day })),
            .target = target,
            .optimize = optimize,
        });
        const base_test_run = b.addRunArtifact(base_test);
        base_test_run.step.dependOn(setup);
        b.step("test", "Test current day").dependOn(&base_test_run.step);

        const base_submit = createRunStep(b, year, current_day, target, optimize, true);
        base_submit.step.dependOn(setup);
        b.step("submit", "Submit current day").dependOn(&base_submit.step);
    }

    const confirm = b.option(bool, "confirm", "Delete all your solutions") orelse false;
    const clean_step = b.step("clean", "Clean all year directories (requires -Dconfirm=true)");
    const clean_ctx = try b.allocator.create(CleanContext);
    clean_ctx.* = .{
        .step = std.Build.Step.init(.{
            .id = .custom,
            .name = "clean-years",
            .owner = b,
            .makeFn = CleanContext.make,
        }),
        .b = b,
        .confirm = confirm,
    };
    clean_step.dependOn(&clean_ctx.step);

    inline for (1..26) |day| {
        const day_num = @as(u9, @intCast(day));
        const day_str = b.fmt("{d}", .{day});
        const setup = createSetupStep(b, year, day_num);
        const run = createRunStep(b, year, day_num, target, optimize, false);
        const run_step = b.step(day_str, b.fmt("Run day {d}", .{day}));
        run.step.dependOn(setup);
        run_step.dependOn(&run.step);

        const test_step = b.step(b.fmt("test:{d}", .{day}), b.fmt("Test day {d}", .{day}));
        test_step.dependOn(&b.addRunArtifact(b.addTest(.{
            .root_source_file = b.path(b.fmt("src/{d}/{d}/solution.zig", .{ year, day_num })),
            .target = target,
            .optimize = optimize,
        })).step);

        const submit = createRunStep(b, year, day_num, target, optimize, true);
        const submit_step = b.step(b.fmt("submit:{d}", .{day}), b.fmt("Submit day {d}", .{day}));
        submit.step.dependOn(setup);
        submit_step.dependOn(&submit.step);
    }
}

const CleanContext = struct {
    step: std.Build.Step,
    b: *std.Build,
    confirm: bool,
    pub fn make(step: *std.Build.Step, options: std.Build.Step.MakeOptions) anyerror!void {
        _ = options;
        const self: *CleanContext = @fieldParentPtr("step", step);
        try cleanYearDirectories(self.b, self.confirm);
    }
};

fn cleanYearDirectories(b: *std.Build, confirm: bool) !void {
    _ = b;
    if (!confirm) {
        std.debug.print("\x1b[91mWARNING: This will delete all your solutions!\n", .{});
        std.debug.print("\x1b[0mYou need to pass the \x1b[93m-Dconfirm=true \x1b[0mflag to confirm.\n", .{});
        return error.MissingConfirmation;
    }

    const stdout = std.io.getStdOut();
    var dir = try std.fs.cwd().openDir("src", .{ .iterate = true });
    defer dir.close();
    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind == .directory) {
            if (std.fmt.parseInt(u16, entry.name, 10)) |_| {
                try dir.deleteTree(entry.name);
                try stdout.writer().print("Deleted src/{s}\n", .{entry.name});
            } else |_| continue;
        }
    }
    try stdout.writer().writeAll("Clean completed successfully.\n");
}

const SetupContext = struct {
    year: u16,
    day: u9,
    b: *std.Build,
    step: std.Build.Step,
    pub fn make(step: *std.Build.Step, options: std.Build.Step.MakeOptions) anyerror!void {
        _ = options;
        const self: *SetupContext = @fieldParentPtr("step", step);
        try ensureDayFiles(self.b, self.year, self.day);
    }
};

fn createSetupStep(b: *std.Build, year: u16, day: u9) *std.Build.Step {
    var ctx = b.allocator.create(SetupContext) catch unreachable;
    ctx.step = std.Build.Step.init(.{ .id = .custom, .name = b.fmt("setup-day{d}", .{day}), .owner = b, .makeFn = SetupContext.make });
    ctx.* = .{ .year = year, .day = day, .b = b, .step = ctx.step };
    return &ctx.step;
}

fn createRunStep(b: *std.Build, year: u16, day: u9, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, submit: bool) *std.Build.Step.Run {
    const CopyContext = struct {
        b: *std.Build,
        year: u16,
        day: u9,
        step: std.Build.Step,
        pub fn make(step: *std.Build.Step, options: std.Build.Step.MakeOptions) anyerror!void {
            const self: *@This() = @fieldParentPtr("step", step);
            const folder = self.b.fmt("src/{d}/{d}", .{ self.year, self.day });
            const source_path = self.b.fmt("{s}/solution.zig", .{folder});

            try std.fs.cwd().makePath(folder);
            const source_file = std.fs.cwd().openFile(source_path, .{}) catch |err| switch (err) {
                error.FileNotFound => {
                    const new_file = try std.fs.cwd().createFile(source_path, .{ .truncate = true });
                    defer new_file.close();
                    try new_file.writeAll(@embedFile("src/template.zig"));
                    return make(step, options);
                },
                else => return err,
            };
            defer source_file.close();

            const content = try source_file.readToEndAlloc(self.b.allocator, std.math.maxInt(usize));
            defer self.b.allocator.free(content);
            const temp_file = try std.fs.cwd().createFile("src/temp_solution.zig", .{ .truncate = true });
            defer temp_file.close();
            try temp_file.writeAll(content);
        }
    };

    var ctx = b.allocator.create(CopyContext) catch unreachable;
    ctx.step = std.Build.Step.init(.{ .id = .custom, .name = b.fmt("copy-solution-{d}", .{day}), .owner = b, .makeFn = CopyContext.make });
    ctx.* = .{ .b = b, .year = year, .day = day, .step = ctx.step };

    const exe = b.addExecutable(.{
        .name = b.fmt("day{d}", .{day}),
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    var options = b.addOptions();
    options.addOption(u16, "year", year);
    options.addOption(u9, "day", day);
    options.addOption(bool, "submit", submit);
    exe.root_module.addOptions("build_options", options);

    const run = b.addRunArtifact(exe);
    run.step.dependOn(&ctx.step);
    return run;
}

fn ensureFileExists(dir: std.fs.Dir, path: []const u8, template_content: []const u8) !void {
    const file = dir.openFile(path, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            const new_file = try dir.createFile(path, .{ .truncate = true });
            defer new_file.close();
            try new_file.writeAll(template_content);
            return;
        },
        else => return err,
    };
    file.close();
}

fn ensureDayFiles(b: *std.Build, year: u16, day: u9) !void {
    const folder = b.fmt("src/{d}/{d}", .{ year, day });
    try std.fs.cwd().makePath(folder);
    try ensureFileExists(std.fs.cwd(), b.fmt("{s}/solution.zig", .{folder}), @embedFile("src/template.zig"));
}
