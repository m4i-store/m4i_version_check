# M4I Store — FiveM version checks

Public, text-only version metadata for M4I FiveM resources, maintained by **M4I Store**.

Each root-level file named after a resource contains **only one version string**. For example:

- [m4i_garage](m4i_garage) — `0.1.140-alpha`
- [m4i_bridge](m4i_bridge) — `1.5.19-rc.1`
- [m4i_upload](m4i_upload) — `0.2.1-alpha`

Keep legacy version metadata (`m4i_identity`, `m4i_interface`) intact unless those products are actively maintained.

## How it works

The included [server-side update.lua template](templates/update.lua) reads `GetResourceMetadata(GetCurrentResourceName(), 'version', 0)` from the local FiveM `fxmanifest.lua`, and compares it to:

`https://raw.githubusercontent.com/m4i-store/m4i_version_check/main/<resource_name>`

The checker prints whether the resource is up to date, newer than the public listing (a development build), or has a newer release available. It uses semantic ordering **dev < alpha < beta < rc < stable**, so prereleases are not falsely considered newer than a stable build. It checks on startup and every 24 hours by default. Network errors or malformed responses never affect resource startup.

The checker **does not download, install, execute, or modify code**. Only version strings are retrieved.

## Install into an M4I resource

Place `update.lua` at the root of the resource and add this in its `fxmanifest.lua`:

```lua
-- M4I Store release notifications (server-only)
server_script 'update.lua'
```

## Settings (server.cfg)

```cfg
# Enable version checks (default true)
set m4i_check_updates true

# Disable for one resource, if needed
set m4i_check_updates_m4i_garage false

# Periodic check interval, 1-168 hours (default 24)
set m4i_update_check_interval_hours 24
```

No framework, SQL table, API token or extra dependency is required.

## Publishing a new version safely

1. Build and test the new script version on staging.
2. Ensure the `version` in its release `fxmanifest.lua` is correct and update the real downloadable asset / Cfx.re Escrow before announcing the release.
3. Edit **only that resource's filename** in this repository to the exact released version (e.g. edit `m4i_garage`).
4. Commit; GitHub Raw updates can be cached briefly, so allow propagation and restart/check again. No need to change customer scripts.
5. Never publish a private unreleased development version as a customer update. A repository update is **notification-only**; availability of a Cfx.re downloadable asset must be managed separately.

## Baseline, 8 November 2026

The 29 resource entries below were initialized from their actual `fxmanifest.lua` versions in M4I's current test/store distribution at setup time. This **baseline is not proof that every version is already published for customers**. Before selling a resource, align its entry with the **actually downloadable** released asset.

Original deployment on M4I RolePlay / QBCore / ESX / Qbox test resources is tracked separately from the official Cfx.re Asset Escrow publishing workflow.

[Full documentation](https://store.m4i.ma/docs)
