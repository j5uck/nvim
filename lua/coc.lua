local notify, window = (function()
  local _ = require("_")
  return _.notify, _.window
end)()

local M = {}

local ALL_EXTENSIONS

M.extensions = {}
M.extensions.required = {
  "coc-clangd",
  "coc-cmake",
  "coc-css",
  "coc-docker",
  "coc-eslint",
  "coc-glslx",
  "coc-go",
  "coc-html",
  "coc-java",
  "coc-jedi",
  "coc-json",
  "coc-kotlin",
  "coc-rust-analyzer",
  "coc-sh",
  "coc-snippets",
  "coc-sql",
  "coc-sumneko-lua",
  "coc-svg",
  "coc-tsserver",
  "coc-typos",

  "@yaegassy/coc-volar",

  -- "coc-marketplace",
  -- "coc-discord-rpc",
}

M.extensions.missing = function()
  local extensionStats = {}
  pcall(function() extensionStats = vim.fn["coc#rpc#request"]("extensionStats", {}) end)

  local filter = {}
  for _, f in ipairs(vim.tbl_map(function(v) return v.id end, extensionStats)) do
    filter[f] = true
  end

  return vim.tbl_filter(function(v)
    return not filter[v]
  end, M.extensions.required)
end

local function is_coc_buffer(b)
  return vim.api.nvim_buf_get_name(b) == "" and
    vim.bo[b].filetype == "" and
    vim.bo[b].buftype  == "nofile"
end

local function set_filetype()
  local t = vim.api.nvim_get_current_tabpage()
  vim.defer_fn(function()
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(t)) do
      local buf = vim.api.nvim_win_get_buf(w)

      if not is_coc_buffer(buf) then goto continue end
      vim.api.nvim_buf_call(buf, function()
        vim.cmd[[set nowrap]]
        vim.cmd[[norm! 0]]
        vim.cmd[[setf coc-nvim]]
      end)
      ::continue::
    end
  end, 500)
end

M.extensions.update = function()
  vim.fn["coc#rpc#notify"]("updateExtensions", {})
  vim.api.nvim_create_autocmd("BufEnter", {
    once = true,
    callback = set_filetype
  })
end

M.extensions.install = function(l)
  if #l == 0 then return end
  for i=1, #l, 8 do
    vim.fn["coc#rpc#notify"]("installExtensions", vim.list_slice(l, i, i+7))
  end
  vim.api.nvim_create_autocmd("BufEnter", {
    once = true,
    callback = set_filetype
  })
end

M.extensions.uninstall = function(l)
  if #l == 0 then return end
  for i=1, #l, 8 do
    vim.fn["coc#rpc#notify"]("uninstallExtension", vim.list_slice(l, i, i+7))
  end
end

local function url(size, page)
  return {
    "node",
    "-e",
    "console.log(" ..
      "await (" ..
        "await fetch(\"" ..
          "https://api.npms.io/v2/search?q=keywords:coc.nvim&size=" .. size .. "&from=" .. page ..
        "\")" ..
      ").text()" ..
    ")"
  }
end

local menu = window:new{
  on_show = function()
    vim.bo.bufhidden  = "delete"
    vim.bo.buflisted  = false
    vim.bo.buftype    = "nofile"
    vim.bo.filetype   = "coc-marketplace"
    vim.bo.modifiable = false
    vim.bo.swapfile   = false
    vim.bo.syntax     = "coc-marketplace"
    vim.bo.undolevels = -1

    vim.wo.cursorline = true

    vim.api.nvim_win_set_config(0, {
      title = " CocMarketplace ",
      title_pos = "center"
    })

    local extensionStats = {}
    pcall(function() extensionStats = vim.fn["coc#rpc#request"]("extensionStats", {}) end)

    local filter = {}
    for _, f in ipairs(vim.tbl_map(function(v) return v.id end, extensionStats)) do
      filter[f] = true
    end

    -- https://github.com/fannheyward/coc-marketplace
    local lines = vim.tbl_map(function(e)
      local sign = filter[e.name] and "✓" or " "
      return string.format("[%s] %-30s %s", sign, e.name, e.description)
    end, ALL_EXTENSIONS)

    vim.bo.modifiable = true
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.bo.modifiable = false

    -- TODO: cache timeout
  end,
  size = function()
    local width = math.min(vim.o.columns - 2, 150)
    local height = math.min(vim.o.lines - 10, #ALL_EXTENSIONS)

    return {
      col    = math.ceil(vim.o.columns - width) * 0.5 - 1,
      row    = math.ceil(vim.o.lines - height)  * 0.5 - 1,
      width  = width,
      height = height
    }
  end,
  focus = true,
  focusable = true,
  border = "rounded",
}

M.marketplace = {}
M.marketplace.option = {}

M.marketplace.option.toggle = function()
  local extensionStats = {}
  pcall(function() extensionStats = vim.fn["coc#rpc#request"]("extensionStats", {}) end)

  local filter = {}
  for _, f in ipairs(vim.tbl_map(function(v) return v.id end, extensionStats)) do
    filter[f] = true
  end

  local min, max = (function()
    local mode = vim.api.nvim_get_mode().mode
    if mode ~= "\022" and string.lower(mode) ~= "v" then
      local r = vim.api.nvim_win_get_cursor(0)[1]
      return r, r
    end

    local a, z = vim.fn.getpos("v")[2], vim.fn.getpos(".")[2]
    if a < z then
      return a, z
    else
      return z, a
    end
  end)()

  for i = min, max, 1 do
    local l = vim.fn.getline(i)
    local sign = string.gsub(l, "^%[(.*)%].*", "%1")

    local new_sign
    local e = ALL_EXTENSIONS[i]

    if filter[e.name] then
      new_sign = sign == "✓" and "✗" or "✓"
    else
      new_sign = sign == " " and "~" or " "
    end

    vim.schedule(function()
      vim.bo.modifiable = true
      vim.fn.setline(i, string.format("[%s] %-30s %s", new_sign, e.name, e.description))
      vim.bo.modifiable = false
    end)
  end

  return "<esc>"
end

M.marketplace.run = function()
  local to_install, to_uninstall = {}, {}

  for i, l in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, true)) do
    local sign = string.gsub(l, "^%[(.*)%].*", "%1")
    if sign == "✗" then
      table.insert(to_uninstall, ALL_EXTENSIONS[i].name)
    elseif sign == "~" then
      table.insert(to_install, ALL_EXTENSIONS[i].name)
    end
  end

  menu:hide()

  if #to_install > 0 then vim.cmd[[tabnew]] end

  local empty_window = vim.api.nvim_get_current_win()

  vim.api.nvim_win_call(empty_window, function()
    M.extensions.uninstall(to_uninstall)
    M.extensions.install(to_install)
  end)

  vim.defer_fn(vim.schedule_wrap(function()
    pcall(vim.api.nvim_win_call, empty_window, vim.cmd.q)
  end), 500)
end

M.marketplace.show = function()
  if ALL_EXTENSIONS then
    menu:show()
    return
   end

  ALL_EXTENSIONS = {}

  local node = vim.fn.exepath("node")
  if node == "" then
    notify.error("Node not found\nCannot proceed")
    return
  end

  local size = 200
  local page = 0

  local function fetch(out)
    if out.code ~= 0 then
      notify.error("Fatal error\n" .. out.stderr)
      return
    end

    local json = vim.json.decode(out.stdout)
    for _, v in ipairs(json.results) do
      table.insert(ALL_EXTENSIONS, {
        name = v.package.name,
        description = v.package.description,
        keywords = v.package.keywords
      })
    end

    page = page + size
    if page < json.total then
      vim.system(url(size, page), { text = true }, fetch)
    else
      vim.schedule(function() menu:show() end)
    end
  end
  vim.system(url(size, page), { text = true }, fetch)
end

return M
