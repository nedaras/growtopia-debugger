const std = @import("std");
const d3d11 = @import("d3d11.zig");
const win = std.os.windows;

const D3D_DRIVER_TYPE = d3d11.D3D_DRIVER_TYPE;
const D3D_FEATURE_LEVEL = d3d11.D3D_FEATURE_LEVEL;

const IDXGIAdapter = d3d11.IDXGIAdapter;
const IDXGISwapChain = d3d11.IDXGISwapChain;
const ID3D11Device = d3d11.ID3D11Device;
const ID3D11DeviceContext = d3d11.ID3D11DeviceContext;

const DXGI_SWAP_CHAIN_DESC = d3d11.DXGI_SWAP_CHAIN_DESC;

pub extern "d3d11" fn D3D11CreateDeviceAndSwapChain(
    pAdapter: ?*IDXGIAdapter,
    DriverType: D3D_DRIVER_TYPE,
    Software: ?win.HMODULE,
    Flags: win.UINT,
    pFeatureLevels: ?[*]const D3D_FEATURE_LEVEL,
    FeatureLevels: win.UINT,
    SDKVersion: win.UINT,
    pSwapChainDesc: ?*const DXGI_SWAP_CHAIN_DESC,
    ppSwapChain: ?**IDXGISwapChain,
    ppDevice: ?**ID3D11Device,
    pFeatureLevel: ?*D3D_FEATURE_LEVEL,
    ppImmediateContext: ?**ID3D11DeviceContext,
) callconv(win.WINAPI) win.HRESULT;
