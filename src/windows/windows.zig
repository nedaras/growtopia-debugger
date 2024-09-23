const std = @import("std");
const kernel32 = @import("kernel32.zig");
const user32 = @import("user32.zig");
const psapi = @import("psapi.zig");
const win = std.os.windows;

pub const d3d11 = @import("d3d11/d3d11.zig");
pub usingnamespace win;

pub const DisableThreadLibraryCallsError = error{Unexpected};

pub fn DisableThreadLibraryCalls(hLibModule: win.HMODULE) DisableThreadLibraryCallsError!void {
    if (kernel32.DisableThreadLibraryCalls(hLibModule) == win.FALSE) {
        switch (win.kernel32.GetLastError()) {
            else => |err| return win.unexpectedError(err),
        }
    }
}

pub const AllocConsoleError = error{
    AllreadyAllocated,
    Unexpected,
};

pub fn AllocConsole() AllocConsoleError!void {
    if (kernel32.AllocConsole() == win.FALSE) {
        switch (win.kernel32.GetLastError()) {
            .ACCESS_DENIED => return AllocConsoleError.AllreadyAllocated,
            else => |err| return win.unexpectedError(err),
        }
    }
}

pub const FreeConsoleError = error{Unexpected};

pub fn FreeConsole() FreeConsoleError!void {
    if (kernel32.FreeConsole() == win.FALSE) {
        switch (win.kernel32.GetLastError()) {
            else => |err| return win.unexpectedError(err),
        }
    }
}

pub const GetModuleHandleAError = error{Unexpected};

pub fn GetModuleHandleA(lpModuleName: ?[:0]const u8) GetModuleHandleAError!win.HMODULE {
    if (lpModuleName) |str| {
        if (kernel32.GetModuleHandleA(str)) |module| {
            return module;
        }
    } else if (kernel32.GetModuleHandleA(null)) |module| {
        return module;
    }

    switch (win.kernel32.GetLastError()) {
        else => |err| return win.unexpectedError(err),
    }
}

pub fn FreeLibraryAndExitThread(hLibModule: win.HMODULE, dwExitCode: u32) void {
    kernel32.FreeLibraryAndExitThread(hLibModule, dwExitCode);
}

pub fn GetForeGroundWindow() ?win.HWND {
    return user32.GetForegroundWindow();
}

pub const GetModuleInformationError = error{Unexpected};

pub fn GetModuleInformation(hProcess: win.HANDLE, hModule: win.HMODULE) GetModuleInformationError!win.MODULEINFO {
    var module_info: win.MODULEINFO = undefined;
    if (psapi.GetModuleInformation(hProcess, hModule, &module_info, @sizeOf(win.MODULEINFO)) == win.FALSE) {
        switch (win.kernel32.GetLastError()) {
            else => |err| return win.unexpectedError(err),
        }
    }
    return module_info;
}

pub const OpenProcessError = error{Unexpected};

pub fn OpenProcess(dwDesiredAccess: win.DWORD, bInheritHandle: win.BOOL, dwProcessId: win.DWORD) OpenProcessError!win.HANDLE {
    if (kernel32.OpenProcess(dwDesiredAccess, bInheritHandle, dwProcessId)) |handle| {
        return handle;
    }

    switch (win.kernel32.GetLastError()) {
        else => |err| return win.unexpectedError(err),
    }
}
