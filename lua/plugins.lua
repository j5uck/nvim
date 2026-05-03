local promisify_wrap, dictionary, flags, fs, git, list, notify, notify_once, prequire_wrap = (function()
  local _ = require("_")
  return _.promisify_wrap, _.dictionary, _.flags, _.fs, _.git, _.list, _.notify, _.notify_once, _.prequire_wrap
end)()

local joinpath = vim.fn.has("win32") == 1 and function(...)
  local r = string.gsub(list.concat({...}, "\\"), "[\\/]+", "\\")
  return r
end or function(...)
  local r = string.gsub(list.concat({...}, "/"), "/+", "/")
  return r
end

local PLUG_HOME = joinpath(vim.fn.stdpath("data"), "plug")
local PLUGS = {}
local PLUGS_ORDER = {}
local PLUG_SYNC = {}

local function runtimepath()
  local rtp, rtp_after = vim.opt.runtimepath:get(), {}
  for i, v in ipairs(rtp) do
    if ({string.gsub(v,"after$","%1")})[2] == 1 then
      rtp, rtp_after = list.slice(rtp, 1, i-1), list.slice(rtp, i, #rtp)
      break
    end
  end

  local exists = {}
  for _, v in ipairs(rtp_after) do
    exists[v] = true
  end

  for _, name in ipairs(PLUGS_ORDER) do
    local d = joinpath(PLUG_HOME, name)
    if (not exists[d]) and vim.fn.isdirectory(d) == 1 then
      list.insert(rtp, d)
      local a = vim.fn.globpath(d, "after")
      if #a > 0 then list.insert(rtp_after, a) end
    end
  end

  vim.opt.runtimepath = list.merge(rtp, rtp_after)
end

PLUG_SYNC.fn = {}
PLUG_SYNC.run_lock = false

local run = promisify_wrap(function(promise, args)
  fs.mkdir(PLUG_HOME):await():unwrap()

  local reltime = vim.fn.reltime()

  if PLUG_SYNC.run_lock then
    return promise:reject("Plug sync is still running")
  end
  PLUG_SYNC.run_lock = true

  if vim.fn.executable("git") == 0 then
    return promise:reject("Git not found")
  end

  local function set_lines(start, _end, lines)
    vim.bo[PLUG_SYNC.buf].modifiable = true
    vim.api.nvim_buf_set_lines(PLUG_SYNC.buf, start, _end, false, lines)
    vim.bo[PLUG_SYNC.buf].modifiable = false
    vim.bo[PLUG_SYNC.buf].modified = false
  end

  -- INIT --

  local todo = { errors = false }
  if #args.fargs == 0 then
    todo.plugs = list.slice(PLUGS_ORDER, 1, #PLUGS_ORDER)
  else
    local missing = {}
    for _, name in ipairs(args.fargs) do
      if not PLUGS[name] then
        list.insert(missing, name)
      end
    end
    if #missing > 0 then
      return promise:reject("Plugin" .. (#missing == 1 and "" or "s") .. " not configured:\n  >>" .. list.concat(missing, "\n  >>"))
    end

    todo.plugs = args.fargs
  end

  if #todo.plugs == 0 then
    notify.warn("Nothing to do")
    return promise:resolve()
  end

  vim.cmd[[tabnew]]
  PLUG_SYNC.buf = vim.api.nvim_get_current_buf()
  PLUG_SYNC.win = vim.api.nvim_get_current_win()

  vim.bo[PLUG_SYNC.buf].filetype   = "lua-plug"
  vim.bo[PLUG_SYNC.buf].bufhidden  = "hide"
  vim.bo[PLUG_SYNC.buf].buflisted  = false
  vim.bo[PLUG_SYNC.buf].buftype    = "nofile"
  vim.bo[PLUG_SYNC.buf].swapfile   = false
  vim.bo[PLUG_SYNC.buf].undolevels = -1

  vim.wo[PLUG_SYNC.win].concealcursor = "nvic"
  vim.wo[PLUG_SYNC.win].conceallevel  = 3

  -- CLEAN UP --

  todo.untracked = (function()
    local l = fs.ls(PLUG_HOME):await():unwrap()

    local u = list.map(function(e)
      return e.name
    end, l)

    return list.filter(function(name)
      return PLUGS[name] == nil
    end, u)
  end)()

  if (#args.fargs == 0) and (#todo.untracked > 0) then
    set_lines(0, -1, { "", "", "", "", "" })
    set_lines(5, -1, list.map(function(v) return "- "..v end, todo.untracked))

    vim.cmd.redraw()
    local answer = vim.fn.input("Delete untracked plugins? (y/N)")

    if vim.fn.match(answer, "^[yY]\\([eE][sS]\\)\\?$") == 0 then
      local promises = {}
      for _, u in ipairs(todo.untracked) do
        local p = fs.remove(joinpath(PLUG_HOME, u))
        p.meta = { untracked = u }
        list.insert(promises, p)
      end
      for _, p in ipairs(promises) do
        if p:await().code ~= 0 then
          notify.error("\"".. p.meta.untracked .."\" couldn't be deleted!")
        end
      end
    end
  end

  todo.untracked = (#args.fargs > 0) and {} or (function()
    local l = fs.ls(PLUG_HOME):await():unwrap()

    local u = list.map(function(e)
      return e.name
    end, l)

    return list.filter(function(name)
      return PLUGS[name] == nil
    end, u)
  end)()
  todo.plugs = list.sort(list.merge(todo.plugs, todo.untracked))
  todo.untracked = nil

  vim.api.nvim_buf_call(PLUG_SYNC.buf, function()
    vim.cmd[[hi link PlugSyncDone Function]]
  end)

  set_lines(0, -1, {})

  -- CLONE --

  todo.promises = {}
  for i, name in ipairs(todo.plugs) do
    local plug = PLUGS[name]
    if not plug then
      set_lines(i-1, i, { "~ " .. name .. ": Untracked" })
      goto continue
    end

    local cwd = joinpath(PLUG_HOME, name)
    if vim.fn.isdirectory(joinpath(cwd, ".git")) == 1 then
      set_lines(i-1, i, { "- " .. name .. ": Cloning... Done!" })
      goto continue
    else
      set_lines(i-1, i, { "+ " .. name .. ": Cloning..." })
    end

    local p = git.clone{ name = name, url = plug.url, cwd = cwd, shallow = true }
    p:finally(function(_p)
      if _p.code == 0 then
        set_lines(i-1, i, { "- " .. name .. ": Cloning... Done!" })
      else
        set_lines(i-1, i, { "x " .. name .. ": Cloning... Error!" })
        notify.error(_p.message)
        todo.errors = true
      end
    end)
    list.insert(todo.promises, p)

    ::continue::
  end

  vim.api.nvim_win_call(PLUG_SYNC.win, function() vim.fn.cursor(1, 2) end)
  for _, p in ipairs(todo.promises) do p:await() end
  if todo.errors then promise:reject() end

  -- FETCH --

  todo.promises = {}
  for i, name in ipairs(todo.plugs) do
    local plug = PLUGS[name]
    if not plug then
      goto continue
    else
      set_lines(i-1, i, { "+ " .. name .. ": Fetching..." })
    end

    local p = git.fetch{
      name = name,
      cwd = joinpath(PLUG_HOME, name),
      commit = plug.commit,
      tag = plug.tag,
      branch = plug.branch,
      shallow = true
    }

    p:finally(function(_p)
      if _p.code == 0 then
        set_lines(i-1, i, { "- " .. name .. ": Fetching... Done!" })
      else
        set_lines(i-1, i, { "x " .. name .. ": Fetching... Error!" })
        notify.error(_p.message)
        todo.errors = true
      end
    end)
    list.insert(todo.promises, p)

    ::continue::
  end

  vim.api.nvim_win_call(PLUG_SYNC.win, function() vim.fn.cursor(1, 2) end)
  for _, p in ipairs(todo.promises) do p:await() end
  if todo.errors then promise:reject() end

  runtimepath()

  -- BUILD --

  todo.promises = {}
  todo.build = {}

  local plugs_i = {}
  for i, name in ipairs(todo.plugs) do
    plugs_i[name] = i
  end

  for _, name in ipairs(PLUGS_ORDER) do
    local i = plugs_i[name]
    if not i then goto continue end

    local build = PLUGS[name].build
    if not build then goto continue end

    set_lines(i-1, i, { "+ " .. name .. ": Building..." })
    list.insert(todo.build, { name = name, i = i, build = build })

    ::continue::
  end

  vim.api.nvim_win_call(PLUG_SYNC.win, function() vim.fn.cursor(1, 2) end)

  for _, p in ipairs(todo.build) do
    local name = p.name
    local i = p.i
    local build = p.build

    local status, result = pcall(function()
      build{ dir = joinpath(PLUG_HOME, name) }
    end)
    if status then
      set_lines(i-1, i, { "- " .. name .. ": Building... Done!" })
    else
      set_lines(i-1, i, { "x " .. name .. ": Building... Error!" })
      notify.error(result)
      todo.errors = true
    end
  end

  if todo.errors then promise:reject() end

  -- FINISH --

  vim.api.nvim_buf_call(PLUG_SYNC.buf, function()
    vim.cmd[[hi link PlugSyncDone Label]]
  end)

  local seconds = string.format("%.3f", vim.trim(vim.fn.reltimestr(vim.fn.reltime(reltime))))
  notify.warn("[LUA-PLUG] Elapsed time: " .. seconds .. " seconds")

  for _, n in ipairs(todo.plugs) do
    vim.cmd("silent! helptags " .. vim.fn.fnameescape(joinpath(PLUG_HOME, n, "doc")))
  end

  promise:resolve()
end)

local function command_sync(args)
  run(args):finally(function(promise)
    PLUG_SYNC.run_lock = false
    if promise.code ~= 0 and #promise.message > 0 then
      notify.error(promise.message)
    end
  end)
end

vim.api.nvim_create_user_command("PlugSync", command_sync, {
  complete = function(search)
    return list.sort(list.filter(function(name)
      return vim.fn.match(name, search) == 0
    end, PLUGS_ORDER))
  end,
  nargs = "*",
  bang = true
})

local function plug(plugin)
  local name = plugin.as or (function()
    local r = plugin[1]
    r = string.gsub(r, ".+/(.+)$", "%1")
    return string.gsub(r, "(.+)%.git$", "%1")
  end)()

  if not PLUGS[name] then list.insert(PLUGS_ORDER, name) end

  PLUGS[name] = {
    url = plugin[1],
    tag = plugin.tag,
    branch = plugin.branch,
    commit = plugin.commit,
    build = plugin.build,
    setup = plugin.setup
  }
end

local function github(p) return "https://github.com/"..p..".git" end


-- ------------------------- x ------------------------- --


-- THEMES --

plug{
  github("catppuccin/nvim"),
  as = "catppuccin",
  setup = prequire_wrap("catppuccin", function(catppuccin)
    catppuccin.setup{
      no_italic = true
    }
  end)
}

plug{
  github("folke/tokyonight.nvim"),
  tag = "stable",
  build = function(_) vim.cmd[[silent! colorscheme tokyonight-storm]] end,
  setup = prequire_wrap("tokyonight", function(tokyonight)
    vim.api.nvim_create_autocmd("ColorScheme", { callback = function()
      if vim.fn.match(vim.g.colors_name, "^tokyonight-.*$") == -1 then return end

      vim.api.nvim_set_hl(0, "WinSeparator", { link = "Comment" })
      vim.api.nvim_set_hl(0, "LineNrAbove",  { link = "Comment" })
      vim.api.nvim_set_hl(0, "LineNr",       { link = "Comment" })
      vim.api.nvim_set_hl(0, "LineNrBelow",  { link = "Comment" })
    end })

    tokyonight.setup{
      terminal_colors = false,
      styles = {
        comments  = { italic = false },
        keywords  = { italic = false },
        functions = {},
        variables = {},
      }
    }
    vim.cmd[[silent! colorscheme tokyonight-storm]]
  end)
}

-- POPUP STYLE MESSAGE --

plug{ github("MunifTanjim/nui.nvim"), tag = "*" }
plug{
  github("rcarriga/nvim-notify"),
  tag = "v*",
  setup = prequire_wrap("notify", function(n)
    n.setup{
      background_colour = "NotifyBackground",
      -- background_colour = "#000000",
      fps = 20,
      icons = {
        DEBUG = "",
        ERROR = "",
        INFO  = "",
        TRACE = "✎",
        WARN  = ""
      },
      level = 2,
      max_height = nil,
      max_width = nil,
      minimum_height = 1,
      minimum_width = 1,
      render = "minimal",
      stages = "fade_in_slide_out",
      timeout = 2500,
      top_down = true
    }

    vim.api.nvim_create_autocmd("CmdlineEnter", {
      pattern = "/",
      callback = function()
        if vim.bo.filetype == "notify" then return end
        for _, id in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          if vim.bo[vim.api.nvim_win_get_buf(id)].filetype == "notify" then
            vim.api.nvim_win_call(id, vim.cmd.q)
          end
        end
      end
    })
  end)
}

plug{
  github("folke/noice.nvim"),
  tag = "v*",
  setup = prequire_wrap("noice", function(noice)
    local FPS = 20
    noice.setup{
      presets = {
        command_palette = true,
        long_message_to_split = false,
      },
      throttle = 1000 / FPS
    }
  end)
}

-- TELESCOPE-NATIVE --

plug{
  github("nvim-telescope/telescope-fzf-native.nvim"),
  build = promisify_wrap(function(promise, opts)
    local cc = vim.fn.exepath("gcc")
    if not cc then
      return promise:reject("GCC not found")
    end

    fs.mkdir(joinpath(opts.dir, "build")):await()

    local target = vim.fn.has("win32") == 1 and "libfzf.dll" or "libfzf.so"
    local cmd = { cc, "-O3", "-fpic", "-std=gnu99", "-shared", "src/fzf.c", "-o", "build/"..target }

    local o  = vim.system(cmd, { text = true, cwd = opts.dir }):wait()
    if o.code ~= 0 then
      return promise:reject("Error compiling fzf:" .. o.stderr)
    end

    promise:resolve()
  end)
}

-- TELESCOPE-UI --

plug{ github("nvim-telescope/telescope-ui-select.nvim") }

-- TELESCOPE --

plug{
  github("nvim-lua/plenary.nvim"),
  tag = "v*"
}
plug{
  github("nvim-telescope/telescope.nvim"),
  -- tag = "*",
  -- tag = "0.1.7",
  commit = "b4da76be54691e854d3e0e02c36b0245f945c2c7",
  setup = prequire_wrap("telescope", function(telescope)
    telescope.setup{
      defaults = {
        history = false,
        file_ignore_patterns = { "^.git/" }
      },
      extensions = {
        ["ui-select"] = {
          dictionary.deep_merge(require("telescope.themes").get_dropdown(), {
            borderchars = {
              prompt  = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
              results = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
            },
            layout_strategy =  "horizontal",
            layout_config = { prompt_position = "top" }
          })
        }
      }
    }
    pcall(telescope.load_extension, "fzf")
    pcall(telescope.load_extension, "noice")
    pcall(telescope.load_extension, "ui-select")
    pcall(telescope.load_extension, "file_browser")
  end)
}

-- TABULATION GUIDES --

plug{
  github("lukas-reineke/indent-blankline.nvim"),
  tag = "v3.*",
  setup = prequire_wrap("ibl", function(ibl)
    ibl.setup{
      scope = {
        enabled = true,
        show_start = false,
        show_end = false
      },
      exclude = {
        filetypes = { "startify", "dashboard" },
        buftypes = { "terminal" }
      }
    }
  end)
}

-- HEX TO COLOR --

plug{
  github("catgoose/nvim-colorizer.lua"),
  -- github("norcalli/nvim-colorizer.lua"),
  commit = "51cf7c995ed1eb6642aecf19067ee634fa1b6ba2",
  setup = prequire_wrap("colorizer", function(colorizer)
    colorizer.setup{
      user_default_options = {
        names = true,
        names_opts = {
          lowercase = true,
          camelcase = true,
          uppercase = true,
          strip_digits = false,
        },

        RGB      = true,
        RGBA     = true,
        RRGGBB   = true,
        RRGGBBAA = true,
        AARRGGBB = true,

        css    = true,
        css_fn = true,

        mode = "background",
        xterm = true
      }
    }
  end)
}

-- MARKDOWN PREVIEW --

plug{
  github("iamcco/markdown-preview.nvim"),
  build = function(_)
    vim.fn["mkdp#util#install"]()
  end,
  setup = function()
    vim.g.mkdp_auto_close = 0
    vim.g.mkdp_page_title = "${name}"
    vim.g.mkdp_theme = "dark"
    -- vim.g.mkdp_preview_options = {
    --   content_editable = false,
    --   disable_filename = 0,
    --   disable_sync_scroll = 0,
    --   flowchart_diagrams = vim.empty_dict(),
    --   hide_yaml_meta = 1,
    --   katex = vim.empty_dict(),
    --   maid = vim.empty_dict(),
    --   mkit = vim.empty_dict(),
    --   sequence_diagrams = vim.empty_dict(),
    --   sync_scroll_type = "middle",
    --   toc = vim.empty_dict(),
    --   uml = vim.empty_dict()
    -- }

    -- TODO: to html & pdf
  end
}

-- TYPST PREVIEW --

plug{
  github("chomosuke/typst-preview.nvim"),
  tag = "v*",
  setup = prequire_wrap("typst-preview", function(typst_preview)
    typst_preview.setup{}
  end)
}

-- BOTTOM STATUS LINE --

plug{ github("nvim-tree/nvim-web-devicons") }
plug{
  github("nvim-lualine/lualine.nvim"),
  setup = prequire_wrap("lualine", function(lualine)
    local extensions = { "man" }

    local PROGRESS, LOCATION = "progress", "location"

    local function ll(filetype, sl, sr)
      sl = sl or {}
      sr = sr or {}
      list.insert(extensions, {
        sections = {
          lualine_a = sl[1] and { sl[1] } or nil,
          lualine_b = sl[2] and { sl[2] } or nil,
          lualine_c = sl[3] and { sl[3] } or nil,
          lualine_x = sr[1] and { sr[1] } or nil,
          lualine_y = sr[2] and { sr[2] } or nil,
          lualine_z = sr[3] and { sr[3] } or nil
        },
        filetypes = { filetype }
      })
    end
    local function fn(o)
      return function() return o end
    end

    local function undotree()
      local target = vim.t.undotree.b.target
      local n = vim.api.nvim_buf_get_name(target)
      local a = (vim.bo[target].modified and "[+]" or "") ..
          (((not vim.bo[target].modifiable) or vim.bo[target].readonly) and "[-]" or "")
      return ((#n == 0) and "[No Name]" or fs.basename(n)) ..
             ((#a == 0) and "" or (" " .. a))
    end

    local function lua_explorer()
      local url = string.gsub(vim.api.nvim_buf_get_name(0), "%%", "%%%%")
      local a = (vim.bo.modified and "[+]" or "") ..
          (((not vim.bo.modifiable) or vim.bo.readonly) and "[-]" or "")
      return url .. ((#a == 0) and "" or (" " .. a))
    end

    ll("help", { fn("NEOVIM HELP"), { "filename", file_status = false } }, { nil, PROGRESS, LOCATION })
    ll("checkhealth", { fn("CHECK HEALTH") }, { nil, PROGRESS, LOCATION })
    ll("TelescopePrompt", { fn("TELESCOPE") })
    ll("undotree", { fn("UNDOTREE"), nil, undotree }, { nil, PROGRESS, LOCATION })

    ll("coc-marketplace", { fn("COC-MARKETPLACE")  }, { nil, PROGRESS, LOCATION })
    ll("coc-nvim", { fn("COC-NVIM") }, { nil, PROGRESS, LOCATION })
    ll("lua-plug", { fn("LUA-PLUG") })
    ll("lua-explorer", { fn("LUA-EXPLORER"), nil, lua_explorer })

    local o = {
      section_separators   = { left = "",  right = ""  },
      component_separators = { left = "|", right = "|" },

      -- section_separators   = { left = "", right = "" },
      -- component_separators = { left = "╲", right = "╱" },

      -- section_separators   = { left = "", right = "" },
      -- component_separators = { left = "", right = "" },

      icons_enabled = true,
      theme = "auto"
    }

    lualine.setup{
      options = o,
      extensions = extensions
    }
  end)
}

-- GIT WRAPPER --

plug{ github("tpope/vim-fugitive") }

-- GIT DECORATION --

plug{
  github("lewis6991/gitsigns.nvim"),
  setup = prequire_wrap("gitsigns", function(gitsigns)
    local s = {
      add          = { text = "+" },
      change       = { text = "~" },
      delete       = { text = "_" },
      topdelete    = { text = "‾" },
      changedelete = { text = "~" }
    }

    gitsigns.setup{
      signs = s,
      signs_staged = s,
      signs_staged_enable = true
    }
  end)
}

-- WINDOW RESIZE --

plug{ github("anuvyklack/middleclass") }
plug{ github("anuvyklack/animation.nvim") }
plug{
  github("anuvyklack/windows.nvim"),
  setup = prequire_wrap("windows", function(windows)
    windows.setup()
    vim.o.winwidth = 10
    vim.o.winminwidth = 10
    vim.o.equalalways = true
    vim.cmd.WindowsDisableAutowidth()

    local commands = {
      "WindowsDisableAutowidth", "WindowsEnableAutowidth",
      "WindowsEqualize", "WindowsMaximize",
      "WindowsMaximizeHorizontally", "WindowsMaximizeVertically",
      "WindowsMaximizeVerticaly", "WindowsToggleAutowidth"
    }
    for _, c in ipairs(commands) do
      pcall(vim.api.nvim_del_user_command, c)
    end
  end)
}

-- AUTO CLOSE TAGS --

-- plug{
--   github("alvan/vim-closetag"),
--   setup = function()
--     vim.g.closetag_filenames = "*.html,*.xhtml,*.phtml"
--     vim.g.closetag_xhtml_filenames = "*.xhtml,*.jsx"
--   end
-- }

-- CTAGS BAR --

-- plug{ github("preservim/tagbar") }

-- AUTO TABSIZE --

plug{ github("tpope/vim-sleuth") }

-- AUTO RENAME TAG --

-- plug{
--   github("windwp/nvim-ts-autotag"),
--   setup = prequire_wrap("nvim-ts-autotag", function(autotag)
--     autotag.setup()
--   end)
-- }

-- TREESITTER --

local ts_extensions = {
  "asm",
  "awk",
  "bash",
  "c",
  "cpp",
  "css",
  "diff",
  "dockerfile",
  "gdscript",
  "git_config",
  "git_rebase",
  "gitattributes",
  "gitcommit",
  "gitignore",
  "glsl",
  "html",
  "hyprlang",
  "javascript",
  "json",
  "json5",
  "jsonc",
  "kotlin",
  -- "latex",
  "lua",
  "luadoc",
  "make",
  "markdown",
  "markdown_inline",
  -- "norg",
  "ocaml",
  "php",
  "printf",
  "python",
  "query",
  "regex",
  "rust",
  "sql",
  "toml",
  "vala",
  "vim",
  "vimdoc",
  "vue",
  "yaml"
}

local setup_nvim_treesitter = prequire_wrap("nvim-treesitter", function(_)
  require("nvim-treesitter.configs").setup{
    --sync_install = true,
      ensure_installed = ts_extensions,
      highlight = {
        enable = true,
        additional_vim_regex_highlighting = false
      },
      indent = { enable = true }
  }
end)

plug{
  github("nvim-treesitter/nvim-treesitter"),
  -- tag = "v*",
  branch = "master",
  build = function(_)
    if vim.fn.exists(":TSUpdate") == 0 then
      setup_nvim_treesitter()
    else
      vim.cmd.TSUpdate()
    end
  end,
  setup = setup_nvim_treesitter
}

-- COC --

plug{ github("rafamadriz/friendly-snippets") }
plug{
  github("neoclide/coc.nvim"),
  branch = "release",
  build = function(_)
    local coc = require("coc")

    if vim.fn.exists("CocUpdate") ~= 0 then
      vim.fn["coc#rpc#restart"]()
    end

    vim.cmd[[belowright vsplit]]

    local empty_window = vim.api.nvim_get_current_win()

    vim.api.nvim_win_call(empty_window, function()
      coc.extensions.update()
      coc.extensions.install(coc.extensions.missing())
    end)

    vim.defer_fn(vim.schedule_wrap(function()
      pcall(vim.api.nvim_win_call, empty_window, vim.cmd.q)
    end), 500)
  end,
  setup = vim.schedule_wrap(function()
    local coc = require("coc")

    if not pcall(vim.fn["coc#pum#visible"]) and flags.warn_missing_module then
      notify_once.warn("Module 'coc' not found")
      return
    end

    pcall(vim.api.nvim_del_user_command, "CocStop")
    vim.api.nvim_create_user_command("CocStop", function() vim.fn["coc#rpc#stop"]() end, {})

    pcall(vim.api.nvim_del_user_command, "CocMarketplace")
    vim.api.nvim_create_user_command("CocMarketplace", coc.marketplace.show, {})
  end)
}


-- ------------------------- x ------------------------- --


runtimepath()

for _, name in ipairs(PLUGS_ORDER) do
  local s = PLUGS[name].setup
  if s then s() end
end
