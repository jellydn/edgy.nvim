local Util = require("edgy.util")

local M = {}

---@alias LayoutTuple {[1]: ("row"|"col"|"leaf"), [2]: window|LayoutTuple[]}

-- Get a list of all the windows in a certain direction
---@param node? LayoutTuple
---@param pos Edgy.Pos
---@param wins? window[]
---@return window[]
function M.get(pos, node, wins)
  wins = wins or {}
  node = node or vim.fn.winlayout()
  if node[1] == "leaf" then
    wins[#wins + 1] = node[2]
  elseif node[1] == "row" then
    if pos == "left" then
      M.get(pos, node[2][1], wins)
    elseif pos == "right" then
      M.get(pos, node[2][#node[2]], wins)
    else
      for _, child in ipairs(node[2]) do
        M.get(pos, child, wins)
      end
    end
  elseif node[1] == "col" then
    if pos == "top" then
      M.get(pos, node[2][1], wins)
    elseif pos == "bottom" then
      M.get(pos, node[2][#node[2]], wins)
    else
      for _, child in ipairs(node[2]) do
        M.get(pos, child, wins)
      end
    end
  end
  return wins
end

function M.needs_layout()
  local Config = require("edgy.config")
  local done = {}
  for _, pos in ipairs({ "left", "right", "bottom", "top" }) do
    local sidebar = Config.layout[pos]
    if sidebar and #sidebar.wins > 0 then
      local wins = vim.tbl_map(function(w)
        return w.win
      end, sidebar.wins)

      local found = vim.tbl_filter(function(w)
        return not vim.tbl_contains(done, w)
      end, M.get(pos))

      vim.list_extend(done, wins)
      if not vim.deep_equal(wins, found) then
        return true
      end
    end
  end
  return false
end

---@param pos Edgy.Pos[]
---@param fn fun(sidebar: Edgy.Sidebar, pos: Edgy.Pos)
function M.foreach(pos, fn)
  local Config = require("edgy.config")
  for _, p in ipairs(pos) do
    if Config.layout[p] then
      fn(Config.layout[p], p)
    end
  end
end

M.updating = false
function M.update()
  if M.updating then
    return
  end

  M.updating = true

  vim.o.winminheight = 0
  vim.o.winminwidth = 1

  vim.o.eventignore = "all"

  -- Don't do anything related to splitkeep while updating
  local splitkeep = vim.o.splitkeep
  vim.o.splitkeep = "cursor"

  Util.try(M._update)

  vim.o.splitkeep = splitkeep
  vim.o.eventignore = ""
  M.updating = false
end

function M._update()
  ---@type table<string, number[]>
  local wins = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
    if ft then
      wins[ft] = wins[ft] or {}
      table.insert(wins[ft], win)
    end
  end
  -- Update the windows in each sidebar
  M.foreach({ "bottom", "top", "left", "right" }, function(sidebar)
    sidebar:update(wins)
    sidebar:state_save()
  end)

  -- Layout the sidebars when needed
  if M.needs_layout() then
    M.foreach({ "bottom", "top", "left", "right" }, function(sidebar)
      sidebar:layout(wins)
    end)
  end

  -- Resize the sidebar windows
  M.foreach({ "left", "right", "bottom", "top" }, function(sidebar)
    sidebar:resize()
  end)

  local Config = require("edgy.config")
  for _, sidebar in pairs(Config.layout) do
    sidebar:state_restore()
  end
end

return M
