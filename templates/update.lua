-- M4I Store | server-side update notifications
-- Source of truth: https://github.com/m4i-store/m4i_version_check
-- This file does not download, execute or install remote code.
if not IsDuplicityVersion() then return end

local resourceName = GetCurrentResourceName()
if type(resourceName) ~= 'string' or not resourceName:match('^m4i_[%w_]+$') then return end

local currentVersion = tostring(GetResourceMetadata(resourceName, 'version', 0) or 'unknown')
local latestURL = 'https://raw.githubusercontent.com/m4i-store/m4i_version_check/main/' .. resourceName
local updatesURL = 'https://store.m4i.ma/docs'
local updateHours = tonumber(GetConvar('m4i_update_check_interval_hours', '24')) or 24
updateHours = math.max(1, math.min(168, updateHours))
local updateIntervalMs = math.floor(updateHours * 60 * 60 * 1000)

local function enabled()
    local function allowed(value)
        value = tostring(value or ''):lower()
        return value ~= 'false' and value ~= '0' and value ~= 'off' and value ~= 'no'
    end
    return allowed(GetConvar('m4i_check_updates', 'true'))
        and allowed(GetConvar('m4i_check_updates_' .. resourceName, 'true'))
end

-- SemVer: 1.2.0-dev < alpha < beta < rc < 1.2.0 (stable).
local function semver(value)
    local major, minor, patch, suffix =
        tostring(value):match('^[vV]?(%d+)%.(%d+)%.(%d+)([%w%.%-]*)$')
    if not major then return nil end
    local rank, number = 4, 0
    if suffix ~= '' then
        local tag, index = suffix:match('^%-([%a]+)%.?(%d*)$')
        local ranks = { dev = 0, alpha = 1, beta = 2, rc = 3 }
        if not tag or ranks[tag] == nil then return nil end
        rank, number = ranks[tag], tonumber(index) or 0
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

local function checkVersion()
    if not enabled() then return end
    PerformHttpRequest(latestURL, function(status, body)
        if status ~= 200 or type(body) ~= 'string' or #body > 96 then
            print(('^3[M4I Store]^7 [%s] Version check unavailable (HTTP %s).'):format(
                resourceName, tostring(status)))
            return
        end

        local latestVersion =
            body:match('^%s*([vV]?%d+%.%d+%.%d+[%w%.%-]*)%s*$')
        if not latestVersion then
            print(('^3[M4I Store]^7 [%s] Invalid version response; update skipped.'):format(resourceName))
            return
        end

        local result = compareVersions(latestVersion, currentVersion)
        if result == nil then
            print(('^3[M4I Store]^7 [%s] Cannot compare versions %s / %s.'):format(
                resourceName, currentVersion, latestVersion))
        elseif result > 0 then
            print(('^3[M4I Store]^7 [%s] ^1UPDATE AVAILABLE^7 | Installed: ^3%s^7 | Latest: ^2%s^7'):format(
                resourceName, currentVersion, latestVersion))
            print(('^5[M4I Store]^7 Info: %s | Assets: https://portal.cfx.re/assets/granted-assets?page=1&search=%s'):format(
                updatesURL, resourceName))
        elseif result < 0 then
            print(('^3[M4I Store]^7 [%s] Local version %s is newer than GitHub listing %s (dev build).'):format(
                resourceName, currentVersion, latestVersion))
        else
            print(('^2[M4I Store]^7 [%s] Up to date: %s'):format(resourceName, currentVersion))
        end
    end, 'GET')
end

local function scheduleCheck()
    checkVersion()
    SetTimeout(updateIntervalMs, scheduleCheck)
end

AddEventHandler('onResourceStart', function(startedResource)
    if startedResource ~= resourceName then return end
    print(('^6[M4I Store]^7 %s loaded | Version ^3%s^7'):format(resourceName, currentVersion))
    -- A small randomized delay prevents many resources from hitting GitHub together.
    SetTimeout(2000 + math.random(0, 18000), scheduleCheck)
end)
