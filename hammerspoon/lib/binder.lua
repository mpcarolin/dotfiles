--- Turns declarative binding rows into registered hotkeys.
---
--- A row is `{ mods, key, <action> }` where exactly one action is set:
---   cmd  = "shell command"   run it; notify if it exits nonzero
---   app  = "App Name"        focus, launching if needed
---          + toggle = true   ...or hide it if already frontmost
---   fn   = function() end    escape hatch for arbitrary Lua
---   choose = { items = fn|table, onSelect = fn, ... }
---                            keyboard-driven popup picker (hs.chooser)
---
--- Any row may also set `requires = "exe"` to declare a tool it needs; a `cmd`
--- row infers this from the command itself.
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

--- A keyboard-driven popup picker, Spotlight-style. `hs.chooser` gives us the
--- type-to-filter field, arrow-key navigation and the native look for free, so
--- this is deliberately thin: it owns when to refresh the list and what to do
--- with a selection, nothing about the UI.
---
--- spec.items     table of choices, or a function returning one. A function is
---                re-invoked on every open, so the list reflects current state.
--- spec.onSelect  called with the chosen item; not called if the user escapes.
--- spec.placeholder / spec.rows / spec.width  optional UI tweaks.
---
--- One chooser object is built per row and reused across invocations: they are
--- cheap to reopen but not free to construct, and reusing it keeps the window
--- position stable.
local function choose(spec)
  local chooser
  return function()
    if not chooser then
      chooser = hs.chooser.new(function(item)
        -- nil means dismissed (escape or click-away) — do nothing.
        if item and spec.onSelect then
          spec.onSelect(item)
        end
      end)
      chooser:placeholderText(spec.placeholder or 'Search')
      chooser:rows(spec.rows or 10)
      chooser:width(spec.width or 30)
      chooser:searchSubText(true)
    end
    local items = type(spec.items) == 'function' and spec.items() or spec.items
    chooser:choices(items or {})
    chooser:query(nil) -- clear the previous search so every open starts fresh
    chooser:show()
  end
end

--- Build the callback for one row, or nil + reason if the row is unusable.
local function callback_for(row)
  -- An explicit dependency, for actions where the tool is not inferable from
  -- the row (a `choose` picker that shells out, say).
  if row.requires and not on_path(row.requires) then
    return nil, ('%q not on PATH'):format(row.requires), true -- skippable
  end

  if row.cmd then
    if not on_path(argv0(row.cmd)) then
      return nil, ('%q not on PATH'):format(argv0(row.cmd)), true -- skippable
    end
    return run(row.cmd)
  elseif row.app then
    return focus(row.app, row.toggle)
  elseif row.fn then
    return row.fn
  elseif row.choose then
    if type(row.choose) ~= 'table' then
      return nil, 'choose must be a table { items = ..., onSelect = ... }'
    end
    if type(row.choose.onSelect) ~= 'function' then
      return nil, 'choose.onSelect must be a function'
    end
    local it = row.choose.items
    if type(it) ~= 'table' and type(it) ~= 'function' then
      return nil, 'choose.items must be a table or a function returning one'
    end
    return choose(row.choose)
  end
  return nil, 'row has no cmd/app/fn/choose action'
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
M.run = run

return M
