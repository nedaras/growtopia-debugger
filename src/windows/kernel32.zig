const std = @import("std");
const win = std.os.windows;

pub extern "kernel32" fn DisableThreadLibraryCalls(hLibModule: win.HMODULE) callconv(win.WINAPI) win.BOOL;

pub extern "kernel32" fn AllocConsole() callconv(win.WINAPI) win.BOOL;

pub extern "kernel32" fn FreeConsole() callconv(win.WINAPI) win.BOOL;

pub extern "kernel32" fn GetModuleHandleA(lpModuleName: ?win.LPCSTR) callconv(win.WINAPI) ?win.HMODULE;

pub extern "kernel32" fn FreeLibraryAndExitThread(hLibModule: win.HMODULE, dwExitCode: win.DWORD) callconv(win.WINAPI) void;

pub extern "kernel32" fn OpenProcess(dwDesiredAccess: win.DWORD, bInheritHandle: win.BOOL, dwProcessId: win.DWORD) callconv(win.WINAPI) ?win.HANDLE;
