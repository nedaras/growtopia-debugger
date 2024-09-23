const std = @import("std");
const win = std.os.windows;

pub extern "psapi" fn GetModuleInformation(hProcess: win.HANDLE, hModule: win.HMODULE, lpmodinfo: *win.MODULEINFO, cb: win.DWORD) callconv(win.WINAPI) win.BOOL;
