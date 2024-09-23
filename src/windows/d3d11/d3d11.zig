const std = @import("std");
const d3d11 = @import("winapi.zig");
const win = std.os.windows;

pub const D3D11Error = @import("D3D11Error.zig").D3D11Error;

pub const D3D_DRIVER_TYPE = win.UINT;
pub const D3D_FEATURE_LEVEL = win.UINT;
pub const DXGI_SWAP_EFFECT = win.UINT;
pub const DXGI_FORMAT = win.UINT;
pub const DXGI_MODE_SCANLINE_ORDER = win.UINT;
pub const DXGI_MODE_SCALING = win.UINT;

pub const DXGI_RATIONAL = extern struct {
    Numerator: win.UINT,
    Denominator: win.UINT,
};

pub const DXGI_MODE_DESC = extern struct {
    Width: win.UINT,
    Height: win.UINT,
    RefreshRate: DXGI_RATIONAL,
    Format: DXGI_FORMAT,
    ScanlineOrdering: DXGI_MODE_SCANLINE_ORDER,
    Scaling: DXGI_MODE_SCALING,
};

pub const DXGI_SAMPLE_DESC = extern struct {
    Count: win.UINT,
    Quality: win.UINT,
};

pub const DXGI_USAGE = win.UINT;

pub const IDXGIAdapter = *opaque {};
pub const IDXGISwapChain = *opaque {};
pub const ID3D11Device = *opaque {};
pub const ID3D11DeviceContext = *opaque {};

pub const DXGI_SWAP_CHAIN_DESC = extern struct {
    BufferDesc: DXGI_MODE_DESC,
    SampleDesc: DXGI_SAMPLE_DESC,
    BufferUsage: DXGI_USAGE,
    BufferCount: win.UINT,
    OutputWindow: win.HWND,
    Windowed: win.BOOL,
    SwapEffect: DXGI_SWAP_EFFECT,
    Flags: win.UINT,
};

pub const D3D11CreateDeviceAndSwapChainError = error{Unexpected};

pub fn D3D11CreateDeviceAndSwapChain(
    pAdapter: ?*IDXGIAdapter,
    DriverType: D3D_DRIVER_TYPE,
    Software: ?win.HMODULE,
    Flags: win.UINT,
    pFeatureLevels: ?[]const D3D_FEATURE_LEVEL,
    SDKVersion: win.UINT,
    pSwapChainDesc: ?*const DXGI_SWAP_CHAIN_DESC,
    ppSwapChain: ?**IDXGISwapChain,
    ppDevice: ?**ID3D11Device,
    pFeatureLevel: ?*D3D_FEATURE_LEVEL,
    ppImmediateContext: ?**ID3D11DeviceContext,
) D3D11CreateDeviceAndSwapChainError!void {
    var feature_levels: ?[*]const D3D_FEATURE_LEVEL = null;
    var feature_levels_len: win.UINT = 0;
    if (pFeatureLevels) |levels| {
        feature_levels = levels.ptr;
        feature_levels_len = @intCast(levels.len);
    }

    const result = d3d11.D3D11CreateDeviceAndSwapChain(pAdapter, DriverType, Software, Flags, feature_levels, feature_levels_len, SDKVersion, pSwapChainDesc, ppSwapChain, ppDevice, pFeatureLevel, ppImmediateContext);
    if (result != win.S_OK) {
        return unexpectedError(result);
    }
}

pub const UnexpectedError = error{
    /// The Operating System returned an undocumented error code.
    ///
    /// This error is in theory not possible, but it would be better
    /// to handle this error than to invoke undefined behavior.
    ///
    /// When this error code is observed, it usually means the Zig Standard
    /// Library needs a small patch to add the error code to the error set for
    /// the respective function.
    Unexpected,
};

pub fn HRESULT_CODE(hr: win.HRESULT) D3D11Error {
    return @enumFromInt(hr);
}

pub fn unexpectedError(hr: win.HRESULT) UnexpectedError {
    const err = HRESULT_CODE(hr);
    std.debug.print("error.Unexpected: D3D11({s})\n", .{
        @tagName(err),
    });
    std.debug.dumpCurrentStackTrace(@returnAddress());
    return error.Unexpected;
}
