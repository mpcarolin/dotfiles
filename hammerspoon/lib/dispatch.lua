--- Turns declarative binding rows into registered hotkeys.
---
--- A row is `{ mods, key, <action> }` where exactly one action is set:
---   cmd  = "shell command"   run it; notify if it exits nonzero
---   app  = "App Name"        focus, launching if needed
---          + toggle = true   ...or hide it if already frontmost
---   fn   = function() end    escape hatch for arbitrary Lua
---
--- Rows are validated at load: an unknown action, a duplicate hotkey, or a
--- command that is not on PATH is reported rather than silently ignored. The
--- PATH check is what keeps this config machine-agnostic — a row whose tool
--- does not exist on this machine is skipped instead of binding a key that
--- errors when pressed.

local M = {}

-- Hammerspoon's own env is not a login shell, so PATH is minimal.
local PATH = os.getenv 'HOME' .. '/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin'

local function notify(title, text)
  hs.notify.new({ title = title, informativeText = text, withdrawAfter = 5 }):send()
end

--- The executable name of a shell command ("theme wallpaper next" -> "theme").
local function argv0(cmd)
  return (cmd:match '^%s*([^%s]+)')
end

local function on_path(exe)
  if exe:find '/' then -- an explicit path, not a PATH lookup
    return hs.fs.attributes(exe) ~= nil
  end
  local _, ok = hs.execute(('PATH=%q command -v %q'):format(PATH, exe))
  return ok == true
end

--- Run a shell command asynchronously, surfacing failure instead of swallowing
--- it. Async matters: `hs.execute` blocks Hammerspoon's main thread, and these
--- commands can take a second or more (a theme switch reloads ghostty and sets
--- the wallpaper), which would freeze every other hotkey meanwhile.
local function run(cmd)
  return function()
    local task = hs.task.new('/bin/sh', function(rc, stdout, stderr)
      if rc ~= 0 then
        local detail = ((stderr or '') .. (stdout or '')):gsub('%s+$', '')
        notify('Shortcut failed: ' .. argv0(cmd), detail .. ' (exit ' .. tostring(rc) .. ')')
      end
    end, { '-c', cmd })
    task:setEnvironment({ PATH = PATH, HOME = os.getenv 'HOME' })
    task:start()
  end
end

--- Focus an app, launching it if it is not running. With toggle, hide it
--- instead when it is already the frontmost app.
local function focus(name, toggle)
  return function()
    local front = hs.application.frontmostApplication()
    if toggle and front and front:name() == name then
      front:hide()
      return
    end
    -- launchOrFocus handles both the running and not-running cases.
    if not hs.application.launchOrFocus(name) then
      notify('Shortcut failed', 'Could not focus ' .. name)
    end
  end
end

--- Build the callback for one row, or nil + reason if the row is unusable.
local function callback_for(row)
  if row.cmd then
    if not on_path(argv0(row.cmd)) then
      return nil, ('%q not on PATH'):format(argv0(row.cmd)), true -- skippable
    end
    return run(row.cmd)
  elseif row.app then
    return focus(row.app, row.toggle)
  elseif row.fn then
    return row.fn
  end
  return nil, 'row has no cmd/app/fn action'
end

--- Register every row. Returns counts for the load summary.
---@param rows table
function M.bind(rows)
  local bound, skipped, errors = 0, 0, {}
  local seen = {}

  for i, row in ipairs(rows) do
    local mods, key = row[1], row[2]
    if type(mods) ~= 'table' or type(key) ~= 'string' then
      table.insert(errors, ('row %d: expected { {mods}, "key", action }'):format(i))
    else
      local id = table.concat(mods, '+'):lower() .. '+' .. key:lower()
      if seen[id] then
        table.insert(errors, ('%s bound twice (rows %d and %d)'):format(id, seen[id], i))
      else
        seen[id] = i
        local cb, why, skippable = callback_for(row)
        if cb then
          hs.hotkey.bind(mods, key, cb)
          bound = bound + 1
        elseif skippable then
          skipped = skipped + 1
        else
          table.insert(errors, ('%s: %s'):format(id, why))
        end
      end
    end
  end

  return { bound = bound, skipped = skipped, errors = errors }
end

M.notify = notify

return M
