---@class EdgyConfig: Edgy.Config
---@field layout table<Edgy.Pos, Edgy.Sidebar>
local M = {}

---@alias Edgy.Pos "bottom"|"top"|"left"|"right"

---@class Edgy.Config
local defaults = {
  ---@type table<Edgy.Pos, Edgy.Sidebar.Opts>
  layout = {},
  icons = {
    closed = " ",
    open = " ",
  },
  animate = {
    enabled = true,
    fps = 100, -- frames per second
    cps = 120, -- cells per second
    on_begin = function()
      vim.g.minianimate_disable = true
    end,
    on_end = function()
      vim.g.minianimate_disable = false
    end,
  },
  -- global window options for sidebar windows
  ---@type vim.wo
  wo = {
    winbar = true,
    winfixwidth = true,
    winfixheight = false,
    winhighlight = "WinBar:EdgyWinBar,Normal:EdgyNormal",
    spell = false,
    signcolumn = "no",
  },
  -- buffer-local keymaps to be added to sidebar buffers
  -- values can be an action (see edgy.actions)
  -- or a function that takes a window.
  -- Existing buffer-local keymaps will never be overridden.
  ---@type table<string, string|fun(win:Edgy.Window)>
  keys = {
    q = "close",
    Q = "close_sidebar",
    ["<c-q>"] = "hide",
  },
  -- enable this on Neovim <= 0.10.0 to
  -- properly fold sidebar windows.
  hacks = false,
  debug = false,
}

---@type Edgy.Config
local options

---@type table<Edgy.Pos, Edgy.Sidebar>
M.layout = {}

---@param opts? Edgy.Config
function M.setup(opts)
  local Sidebar = require("edgy.sidebar")
  local Layout = require("edgy.layout")

  opts = vim.tbl_deep_extend("force", defaults, opts or {})
  options = opts

  for pos, s in pairs(opts.layout) do
    M.layout[pos] = Sidebar.new(pos, s)
  end

  if options.hacks then
    require("edgy.hacks").setup()
  end

  vim.api.nvim_set_hl(0, "EdgyIcon", { default = true, link = "SignColumn" })
  vim.api.nvim_set_hl(0, "EdgyTitle", { default = true, link = "Title" })
  vim.api.nvim_set_hl(0, "EdgyWinBar", { default = true, link = "Winbar" })
  vim.api.nvim_set_hl(0, "EdgyNormal", { default = true, link = "NormalFloat" })

  require("edgy.editor").setup()

  local group = vim.api.nvim_create_augroup("layout", { clear = true })
  vim.api.nvim_create_autocmd({ "BufWinEnter", "WinClosed", "WinNew", "WinResized" }, {
    group = group,
    callback = Layout.update,
  })
  vim.api.nvim_create_autocmd({ "FileType", "VimResized" }, {
    callback = function()
      vim.schedule(Layout.update)
    end,
  })
  Layout.update()
end

return setmetatable(M, {
  __index = function(_, key)
    if options == nil then
      return vim.deepcopy(defaults)[key]
    end
    ---@cast options Edgy.Config
    return options[key]
  end,
})
