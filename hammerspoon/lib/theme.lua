--- A popup theme picker for the `theme` switcher (dotfiles/bin/theme).
---
--- Tracked and machine-agnostic: this module only describes a picker. Binding
--- it to a key is a row in a bindings file, and dispatch skips that row on a
--- machine where `theme` is not on PATH.

local dispatch = require 'lib.dispatch'

local M = {}

--- Themes as chooser choices, newest state every time the picker opens.
--- Parses `theme list --porcelain` (NAME<TAB>BACKGROUND<TAB>ACTIVE), which
--- exists so this does not have to scrape the human-readable format.
local function themes()
  local out, ok = hs.execute('theme list --porcelain', true) -- true: login shell, for PATH
  if not ok then
    dispatch.notify('Theme picker', 'Could not run `theme list`')
    return {}
  end

  local choices = {}
  for line in out:gmatch '[^\n]+' do
    local name, background, active = line:match '^([^\t]+)\t([^\t]*)\t([^\t]*)$'
    if name then
      local subText = background
      if active == 'active' then
        subText = background .. ' — active'
      end
      table.insert(choices, {
        text = name,
        subText = subText,
        theme = name,
        -- Sort the active theme to the top so reopening the picker starts on it.
        active = active == 'active',
      })
    end
  end

  table.sort(choices, function(a, b)
    if a.active ~= b.active then
      return a.active
    end
    return a.text < b.text
  end)

  return choices
end

--- The `choose` spec for a theme picker. Use it as a binding row:
---   { { 'cmd', 'shift' }, 'P', choose = require('lib.theme').picker() }
function M.picker()
  return {
    placeholder = 'Theme',
    rows = 13,
    width = 25,
    items = themes,
    onSelect = function(item)
      dispatch.run('theme set ' .. ("%q"):format(item.theme))()
    end,
  }
end

return M
