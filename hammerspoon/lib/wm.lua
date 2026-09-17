--- Hyprland-style window geometry: halves, fullscreen, center.
---
--- Tracked and machine-agnostic: pure hs.window/hs.screen math, no app or
--- tool dependency. This is a Hammerspoon-level "maximize"/"snap", distinct
--- from macOS's native green-button Spaces fullscreen.

local M = {}

--- Gap kept between a window and the screen edge (and between two halves),
--- in points. Starting value; adjust live with M.increase_padding /
--- M.decrease_padding.
M.padding = 8

local PADDING_STEP = 4

--- Run fn with the focused window and its visible screen frame, or no-op if
--- there is no focused window (e.g. focus is on the Desktop).
---@param fn fun(win: hs.window, frame: hs.geometry)
local function with_focused(fn)
  local win = hs.window.focusedWindow()
  if not win then
    return
  end
  fn(win, win:screen():frame())
end

--- Inset a rect on whichever sides border the screen edge, so `padding`
--- always separates a window from the edge and from its neighbor across a
--- half-split (which is inset on both sides once, by each window).
---@param r table {x, y, w, h}
---@param f hs.geometry full screen frame, to detect which sides are edges
---@param p number padding in points; defaults to M.padding
local function inset(r, f, p)
  p = p or M.padding
  local left = r.x <= f.x
  local top = r.y <= f.y
  local right = (r.x + r.w) >= (f.x + f.w)
  local bottom = (r.y + r.h) >= (f.y + f.h)

  local x1, y1 = r.x + (left and p or p / 2), r.y + (top and p or p / 2)
  local x2 = r.x + r.w - (right and p or p / 2)
  local y2 = r.y + r.h - (bottom and p or p / 2)

  return { x = x1, y = y1, w = x2 - x1, h = y2 - y1 }
end

--- Unpadded rect for each snap layout, keyed by name. Shared between the
--- direct bindings below and set_padding's reapply-on-change.
local LAYOUTS = {
  left_half = function(f)
    return { x = f.x, y = f.y, w = f.w / 2, h = f.h }
  end,
  right_half = function(f)
    return { x = f.x + f.w / 2, y = f.y, w = f.w / 2, h = f.h }
  end,
  top_half = function(f)
    return { x = f.x, y = f.y, w = f.w, h = f.h / 2 }
  end,
  bottom_half = function(f)
    return { x = f.x, y = f.y + f.h / 2, w = f.w, h = f.h / 2 }
  end,
  fullscreen = function(f)
    return f
  end,
}

for name, rect in pairs(LAYOUTS) do
  M[name] = function()
    with_focused(function(win, f)
      win:setFrame(inset(rect(f), f))
    end)
  end
end

--- Centered at ~85% of the screen's width/height (roughly double the area of
--- a 60% frame). Padding does not apply here — the frame is already well
--- clear of the edges by construction.
function M.center()
  with_focused(function(win, f)
    local w, h = f.w * 0.85, f.h * 0.85
    win:setFrame { x = f.x + (f.w - w) / 2, y = f.y + (f.h - h) / 2, w = w, h = h }
  end)
end

--- If the focused window's frame already matches one of LAYOUTS (inset by
--- padding_before), re-set it with M.padding so the adjustment is visible
--- immediately. Left alone otherwise.
local function reapply_current_layout(padding_before)
  with_focused(function(win, f)
    local g = win:frame()
    for _, rect in pairs(LAYOUTS) do
      local prior = inset(rect(f), f, padding_before)
      if math.abs(prior.x - g.x) < 2 and math.abs(prior.y - g.y) < 2 and math.abs(prior.w - g.w) < 2 and math.abs(prior.h - g.h) < 2 then
        win:setFrame(inset(rect(f), f))
        return
      end
    end
  end)
end

--- Changes take effect immediately on the focused window if it is currently
--- snapped to one of our layouts; otherwise applies to the next placement.
local function set_padding(p)
  local padding_before = M.padding
  M.padding = math.max(0, p)
  hs.alert.closeAll()
  hs.alert.show('Window padding: ' .. M.padding, 0.6)
  reapply_current_layout(padding_before)
end

function M.increase_padding()
  set_padding(M.padding + PADDING_STEP)
end

function M.decrease_padding()
  set_padding(M.padding - PADDING_STEP)
end

return M
