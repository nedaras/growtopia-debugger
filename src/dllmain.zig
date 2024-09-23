const std = @import("std");
const win = @import("windows/windows.zig");

pub export fn DllMain(instance: win.HINSTANCE, reason: win.DWORD, reserved: win.LPVOID) callconv(win.WINAPI) win.BOOL {
    // never freeing console so user could read why it failed why? cuz we cant hold DLLMain
    // and use console only on debug mode release mode write to a file
    // todo: for release add like file writer
    if (reason == 1) {
        win.AllocConsole() catch |err| switch (err) {
            error.AllreadyAllocated => {},
            else => {
                // todo: add win message box
                return win.FALSE;
            },
        };
    }

    const result = TracedDllMain(instance, reason, reserved) catch |err| {
        std.debug.print("error: {s}\n", .{@errorName(err)});
        if (@errorReturnTrace()) |trace| {
            std.debug.dumpStackTrace(trace.*);
        }
        return win.FALSE;
    };

    return switch (result) {
        true => win.TRUE,
        false => win.FALSE,
    };
}

inline fn TracedDllMain(instance: win.HINSTANCE, reason: win.DWORD, _: win.LPVOID) !bool {
    if (reason == 1) {
        try win.DisableThreadLibraryCalls(@ptrCast(instance));

        const thread = try std.Thread.spawn(.{}, wrapped, .{instance});
        thread.detach();

        return true;
    }
    return false;
}

fn wrapped(instance: win.HINSTANCE) void {
    // todo: we need a trace no idea how to fix, we need to relink pdb or place in injected spot
    @import("main.zig").main() catch |err| {
        std.debug.print("error: {s}\n", .{@errorName(err)});
        if (@errorReturnTrace()) |trace| {
            std.debug.dumpStackTrace(trace.*);
        }

        std.debug.print("\n\npress enter couple times to exit...\n", .{});

        const stdin = std.io.getStdIn();
        _ = stdin.reader().readByte() catch {};
    };

    win.FreeConsole() catch {}; // theres nothing we can do
    win.FreeLibraryAndExitThread(@ptrCast(instance), 0);
}
