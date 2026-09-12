--- Hammerspoon entry point. Keyboard shortcuts as data, not code.
---
--- Bindings live in `bindings.lua` (tracked, cross-machine) and
--- `bindings.local.lua` (gitignored, this machine only). To add a shortcut,
--- add a row — never an `hs.hotkey.bind` call. See lib/dispatch.lua for the
--- row format and the four action types.

-- `hs.ipc` backs the `hs` command-line tool, which is how this config can be
-- inspected and reloaded from a shell.
require 'hs.ipc'

local dispatch = require 'lib.dispatch'

--- Load a binding table from a file in the config dir.
---
--- Loaded by PATH, not by `require`: the local file is `bindings.local.lua`,
--- and `require 'bindings.local'` would look for `bindings/local.lua` instead.
--- A missing optional file is fine; anything else (syntax error, bad return)
--- is reported so it cannot fail silently.
---@param file string filename relative to the config dir
---@param optional boolean true if absence is expected
local function load_bindings(file, optional)
  local path = hs.configdir .. '/' .. file

  if not hs.fs.attributes(path) then
    if not optional then
      dispatch.notify('Hammerspoon: missing ' .. file, path)
    end
    return {}
  end

  local chunk, err = loadfile(path)
  if not chunk then
    dispatch.notify('Hammerspoon: ' .. file .. ' has a syntax error', tostring(err))
    return {}
  end

  local ok, mod = pcall(chunk)
  if not ok then
    dispatch.notify('Hammerspoon: ' .. file .. ' failed to load', tostring(mod))
    return {}
  end
  if type(mod) ~= 'table' then
    dispatch.notify('Hammerspoon: ' .. file .. ' must return a table', 'got ' .. type(mod))
    return {}
  end
  return mod
end

local rows = {}
for _, source in ipairs { { 'bindings.lua', false }, { 'bindings.local.lua', true } } do
  for _, row in ipairs(load_bindings(source[1], source[2])) do
    table.insert(rows, row)
  end
end

local result = dispatch.bind(rows)

-- Reload the config on any change to the dotfiles hammerspoon dir.
local configWatcher = hs.pathwatcher.new(hs.configdir, function(paths)
  for _, p in ipairs(paths) do
    if p:match '%.lua$' then
      hs.reload()
      return
    end
  end
end):start()
-- Keep a reference so the watcher is not garbage-collected.
_G.__configWatcher = configWatcher

-- A manual reload hotkey, useful while editing bindings.
hs.hotkey.bind({ 'cmd', 'alt', 'ctrl' }, 'R', hs.reload)

--- Load summary. Errors are worth an alert; a clean load should be quiet
--- beyond a brief confirmation.
if #result.errors > 0 then
  hs.alert.show('Hammerspoon: ' .. #result.errors .. ' binding error(s)\n' .. table.concat(result.errors, '\n'), 6)
else
  local msg = result.bound .. ' shortcuts'
  if result.skipped > 0 then
    msg = msg .. ' (' .. result.skipped .. ' skipped)'
  end
  hs.alert.show(msg, 1)
end
