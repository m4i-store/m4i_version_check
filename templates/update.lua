-- M4I Store | Server-only update notifications
-- Published versions: https://github.com/m4i-store/m4i_version_check
-- The checker never downloads, executes, or installs remote code.
if not IsDuplicityVersion() then return end

local runtimeResource = GetCurrentResourceName()
-- Stable product ID from fxmanifest.lua name metadata, NOT the folder name.
local manifestName = GetResourceMetadata(runtimeResource, 'name', 0)
local productName = tostring(manifestName or runtimeResource)
local installedVersion = tostring(GetResourceMetadata(runtimeResource, 'version', 0) or 'unknown')

local function enabled()
    -- Customer-editable setting: config/update.lua
    if type(M4IUpdateConfig) == 'table' and M4IUpdateConfig.check_update == false then
        return false
    end
    local function allowed(value)
        value = tostring(value or ''):lower()
        return value ~= 'false' and value ~= '0' and value ~= 'off' and value ~= 'no'
    end
    return allowed(GetConvar('m4i_check_updates', 'true'))
        and allowed(GetConvar('m4i_check_updates_' .. productName, 'true'))
end

local function semver(value)
    local major, minor, patch, suffix =
        tostring(value):match('^[vV]?(%d+)%.(%d+)%.(%d+)([%w%.%-]*)$')
    if not major then return nil end
    local rank, number = 4, 0
    if suffix ~= '' then
        local tag, index = suffix:match('^%-([%a]+)%.?(%d*)$')
        local order = { dev = 0, alpha = 1, beta = 2, rc = 3 }
        if not tag or order[tag] == nil then return nil end
        rank, number = order[tag], tonumber(index) or 0
    end
    return { tonumber(major), tonumber(minor), tonumber(patch), rank, number }
end

local function compareVersions(remote, installed)
    local a, b = semver(remote), semver(installed)
    if not a or not b then return nil end
    for i = 1, 5 do
        if a[i] > b[i] then return 1 end
        if a[i] < b[i] then return -1 end
    end
    return 0
end

local latestURL = 'https://raw.githubusercontent.com/m4i-store/m4i_version_check/main/' .. productName
local intervalHours = tonumber(GetConvar('m4i_update_check_interval_hours', '24')) or 24
intervalHours = math.max(1, math.min(168, intervalHours))
local intervalMs = math.floor(intervalHours * 60 * 60 * 1000)

local function checkVersion()
    if not enabled() then return end
    PerformHttpRequest(latestURL, function(status, body)
        if status ~= 200 or type(body) ~= 'string' or #body > 96 then
            print(('^3[M4I Store]^7 [%s] Version check unavailable (HTTP %s).'):format(
                productName, tostring(status)))
            return
        end
        local latest = body:match('^%s*([vV]?%d+%.%d+%.%d+[%w%.%-]*)%s*$')
        if not latest then
            print(('^3[M4I Store]^7 [%s] Invalid version response; skipped.'):format(productName))
            return
        end
        local result = compareVersions(latest, installedVersion)
        if result == nil then
            print(('^3[M4I Store]^7 [%s] Cannot compare version %s / %s.'):format(
                productName, installedVersion, latest))
        elseif result > 0 then
            print(('^3[M4I Store]^1 [%s] UPDATE AVAILABLE!^7 Installed: ^3%s^7 | Latest: ^2%s^7'):format(
                productName, installedVersion, latest))
            print(('^5[M4I Store]^7 Download: https://portal.cfx.re/assets/granted-assets?page=1&search=%s'):format(
                productName))
        elseif result < 0 then
            print(('^3[M4I Store]^7 [%s] Local version %s is newer than GitHub %s (dev build).'):format(
                productName, installedVersion, latest))
        else
            print(('^2[M4I Store]^7 [%s] You are running the latest version: %s'):format(
                productName, installedVersion))
        end
    end, 'GET')
end

local function scheduleNext()
    if not enabled() then return end
    checkVersion()
    SetTimeout(intervalMs, scheduleNext)
end

AddEventHandler('onResourceStart', function(started)
    if started ~= runtimeResource then return end

    print([[
███╗   ███╗██╗  ██╗██╗    ███████╗████████╗ ██████╗ ██████╗ ███████╗
████╗ ████║██║  ██║██║    ██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗██╔════╝
██╔████╔██║███████║██║    ███████╗   ██║   ██║   ██║██████╔╝█████╗
██║╚██╔╝██║╚════██║██║    ╚════██║   ██║   ██║   ██║██╔══██╗██╔══╝
██║ ╚═╝ ██║     ██║██║    ███████║   ██║   ██║   ██║██╔══██╗██╔══╝
╚═╝     ╚═╝     ╚═╝╚═╝    ╚══════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝
]])

    print(('^2[M4I Store]^7 %s loaded | Version ^3%s^7'):format(
        productName, installedVersion))

    -- Invalid name metadata must never become an untrusted URL path.
    if not productName:match('^m4i_[%w_]+$') then
        print(('^1[M4I Store]^7 Invalid fxmanifest name for %s; update check skipped.'):format(
            runtimeResource))
        return
    end
    if not enabled() then
        print(('^3[M4I Store]^7 [%s] Update checks disabled in config/update.lua or server.cfg.'):format(
            productName))
        return
    end

    -- Spread startup requests when multiple M4I resources start simultaneously.
    SetTimeout(2000 + math.random(0, 18000), scheduleNext)
end)
