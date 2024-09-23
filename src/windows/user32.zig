const std = @import("std");
const win = std.os.windows;

pub extern "user32" fn GetForegroundWindow() ?win.HWND;
