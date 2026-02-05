local flags, fs, git, notify, notify_once, prequire_wrap = (function()
  local _ = require("_")
  return _.flags, _.fs, _.git, _.notify, _.notify_once, _.prequire_wrap
end)()

local joinpath = vim.fn.has("win32") == 1 and function(...)
  local r = string.gsub(table.concat({...}, "\\"), "[\\/]+", "\\")
  return r
end or function(...)
  local r = string.gsub(table.concat({...}, "/"), "/+", "/")
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
      rtp, rtp_after = vim.list_slice(rtp, 1, i-1), vim.list_slice(rtp, i, #rtp)
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
      table.insert(rtp, d)
      local a = vim.fn.globpath(d, "after")
      if #a > 0 then table.insert(rtp_after, a) end
    end
  end

  vim.opt.runtimepath = vim.list_extend(rtp, rtp_after)
end

PLUG_SYNC.fn = {}
PLUG_SYNC.fn.run_lock = false
PLUG_SYNC.fn.run = function(args)
  if PLUG_SYNC.fn.run_lock then return end

  PLUG_SYNC.coroutine = coroutine.create(function()
    PLUG_SYNC.fn.run_lock = true
    PLUG_SYNC.fn.run_coroutine()
    PLUG_SYNC.fn.run_lock = false
  end)

  coroutine.resume(PLUG_SYNC.coroutine, args)
end

PLUG_SYNC.fn.run_coroutine = function(args)
  if vim.fn.executable("git") == 0 then
    return notify.error("Git not found\nCannot proceed")
  end

  local po = vim.fn.sort(#args.fargs > 0 and args.fargs or PLUGS_ORDER, "i")
  if #po == 0 then return notify.warn("Nothing to do") end

  PLUG_SYNC.reltime = vim.fn.reltime()

  vim.cmd[[tabnew]]
  PLUG_SYNC.buf = vim.api.nvim_get_current_buf()

  vim.bo.bufhidden    = "hide"
  vim.bo.buflisted    = false
  vim.bo.buftype      = "nofile"
  vim.bo.swapfile     = false
  vim.bo.undolevels   = -1
  vim.o.concealcursor = "nvic"
  vim.o.conceallevel  = 3

  vim.cmd[[setf lua-plug]]
  for _, v in ipairs{ "<CR>", "x", "X", "d", "dd", "i", "I", "a", "A", "o", "O", "r", "R" } do
    vim.keymap.set("n", v, "<Nop>", { buffer = PLUG_SYNC.buf })
  end
  vim.keymap.set("n", "q", "<cmd>q<CR>", { buffer = PLUG_SYNC.buf })
  if vim.fn.exists('+colorcolumn') == 1 then
    vim.cmd[[setlocal colorcolumn=]]
  end

  if #args.fargs > 0 then PLUG_SYNC.fn.clean() end

  vim.api.nvim_buf_call(PLUG_SYNC.buf, function()
    vim.cmd[[hi link PlugSyncDone Function]]
  end)

  local not_finished = #po
  local error = false
  for i = 1, #po, 1 do
    local name = po[i]
    local index = i
    vim.bo[PLUG_SYNC.buf].modifiable = true
    vim.api.nvim_buf_set_lines(PLUG_SYNC.buf, index-1, index, false, {
      "+ " .. name .. ": Fetching..."
    })
    vim.bo[PLUG_SYNC.buf].modifiable = false

    local cwd = joinpath(PLUG_HOME, name)
    local plug = PLUGS[name]
    local f_options = { name = name, cwd = cwd, commit = plug.commit, tag = plug.tag, branch = plug.branch }
    local callback = vim.schedule_wrap(function(ok)
      vim.bo[PLUG_SYNC.buf].modifiable = true
      if ok then
        vim.api.nvim_buf_set_lines(PLUG_SYNC.buf, index-1, index, false, {
          "- " .. name .. ": Fetching... Done!"
        })
      else
        vim.api.nvim_buf_set_lines(PLUG_SYNC.buf, index-1, index, false, {
          "x " .. name .. ": Fetching... ERROR!"
        })
        error = true
      end
      not_finished = not_finished - 1
      vim.bo[PLUG_SYNC.buf].modifiable = false
      vim.schedule_wrap(coroutine.resume)(PLUG_SYNC.coroutine)
    end)

    if vim.fn.isdirectory(joinpath(cwd, ".git")) == 0 then
      git.clone({ name = name, url = plug.uri, cwd = cwd }, function(ok)
        if not ok then return callback(false) end
        git.fetch(f_options, callback)
      end)
    else
      git.fetch(f_options, callback)
    end
  end

  vim.fn.cursor(1, 2)
  while not_finished > 0 do
    coroutine.yield()
  end

  if error then return end

  runtimepath()

  for i = 1, #po, 1 do
    local name = po[i]
    local index = i
    local build = PLUGS[name].build
    if not build then goto continue end

    vim.bo[PLUG_SYNC.buf].modifiable = true
    vim.api.nvim_buf_set_lines(PLUG_SYNC.buf, index-1, index, false, {
      "+ " .. name .. ": Building..."
    })
    vim.bo[PLUG_SYNC.buf].modifiable = false

    local s, msg = pcall(function()
      build{ dir = joinpath(PLUG_HOME, name) }
      vim.bo[PLUG_SYNC.buf].modifiable = true
      vim.api.nvim_buf_set_lines(PLUG_SYNC.buf, index-1, index, false, {
        "- " .. name .. ": Building... Done!"
      })
      vim.bo[PLUG_SYNC.buf].modifiable = false
    end)
    if not s then
      error = true
      vim.bo[PLUG_SYNC.buf].modifiable = true
      vim.api.nvim_buf_set_lines(PLUG_SYNC.buf, index-1, index, false, {
        "x " .. name .. ": Building... ERROR!"
      })
      vim.bo[PLUG_SYNC.buf].modifiable = false
      notify.error(msg)
    end

    ::continue::
  end

  if error then return end

  vim.api.nvim_buf_call(PLUG_SYNC.buf, function()
    vim.cmd[[hi link PlugSyncDone Label]]
  end)
  local seconds = string.format("%.3f", vim.trim(vim.fn.reltimestr(vim.fn.reltime(PLUG_SYNC.reltime))))
  notify.warn("[LUA-PLUG] Elapsed time: " .. seconds .. " seconds")

  for _, n in ipairs(po) do
    vim.cmd("silent! helptags " .. vim.fn.fnameescape(joinpath(PLUG_HOME, n, "doc")))
  end
end

PLUG_SYNC.fn.clean = function()
  local len = #(joinpath(PLUG_HOME, "/"))+1

  local untracked = vim.tbl_filter(function(v)
    return PLUGS[string.sub(v,len)] == nil
  end, vim.fn.globpath(PLUG_HOME, "*", true, true)) -- dot files are ignored

  if #untracked == 0 then return end

  vim.bo[PLUG_SYNC.buf].modifiable = true
  vim.api.nvim_buf_set_lines(PLUG_SYNC.buf, 0, -1, false, {"","","",""})
  vim.api.nvim_buf_set_lines(PLUG_SYNC.buf, 4, -1, false,
    vim.tbl_map(function(v) return "- "..v end, untracked)
  )
  vim.bo[PLUG_SYNC.buf].modifiable = false
  vim.bo[PLUG_SYNC.buf].modified = false

  vim.cmd.redraw()
  local answer = vim.fn.input("Delete untracked directories? (y/N)")

  if vim.fn.match(answer, "^[yY]") == 0 then
    untracked = vim.tbl_filter(function(u)
      local s = vim.fn.delete(u,"rf") ~= 0
      if s then notify.error("\""..u.."\" couldn't be delete!") end
      return s
    end, untracked)
  end

  local u = vim.fn.sort(vim.tbl_map(function(v) return string.sub(v,#PLUG_HOME+2) end, untracked), "i")
  for _, name in ipairs(u) do
    table.insert(PLUG_SYNC.text, "~ " .. name .. ": Untracked")
  end
end

vim.api.nvim_create_user_command("PlugSync", PLUG_SYNC.fn.run, {
  complete = function(search)
    return vim.fn.sort(vim.tbl_filter(function(name)
      return vim.fn.match(name, search) == 0
    end, PLUGS_ORDER), "i")
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

  if not PLUGS[name] then table.insert(PLUGS_ORDER, name) end

  PLUGS[name] = {
    uri = plugin[1],
    tag = plugin.tag,
    branch = plugin.branch,
    commit = plugin.commit,
    build = plugin.build,
    setup = plugin.setup
  }
end

local function github(p) return "https://github.com/"..p..".git" end


----- ----- ----- ----- ----- X ----- ----- ----- ----- -----


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
      -- background_colour = ""#000000",
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
  build = function(opts)
    local cc = vim.fn.exepath("gcc")
    if not cc then return notify.error("GCC not found") end

    fs.mkdir(joinpath(opts.dir, "build"))

    local target = vim.fn.has("win32") == 1 and "libfzf.dll" or "libfzf.so"
    local cmd = { cc, "-O3", "-fpic", "-std=gnu99", "-shared", "src/fzf.c", "-o", "build/"..target }

    local o  = vim.system(cmd, { text = true, cwd = opts.dir }):wait()
    if o.code ~= 0 then notify.error("Error compiling fzf:" .. o.stderr) end
  end
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
          vim.tbl_deep_extend("force", require("telescope.themes").get_dropdown(), {
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
  end
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
      table.insert(extensions, {
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
    local function fn(o) return function() return o end end

    ll("help", { fn("NEOVIM HELP"), { "filename", file_status = false } }, { nil, PROGRESS, LOCATION })
    ll("checkhealth", { fn("CHECK HEALTH") }, { nil, PROGRESS, LOCATION })
    ll("TelescopePrompt", { fn("TELESCOPE") })
    ll("undotree", { fn("UNDOTREE"), nil, function()
      local n = vim.api.nvim_buf_get_name(vim.t.undotree.b.target)
      if #n == 0 then return "[No Name]" end
      return fs.basename(n)
    end }, { nil, PROGRESS, LOCATION })

    ll("coc-marketplace", { fn("COC-MARKETPLACE")  }, { nil, PROGRESS, LOCATION })
    ll("coc-nvim", { fn("COC-NVIM") }, { nil, PROGRESS, LOCATION })
    ll("lua-plug", { fn("LUA-PLUG") })
    ll("lua-explorer", {
      fn("LUA-EXPLORER"),
      nil,
      function()
        local url = string.gsub(vim.api.nvim_buf_get_name(0), "%%", "%%%%")
        return vim.o.modified and (url .. " [+]") or url
      end
    })

    local o = { icons_enabled = true, theme = "auto" }

    -- if vim.g.nvy then
    if (vim.fn.has("win32") == 0) and fs.readfile("/etc/hostname")[1] == "host7" then
      o.section_separators   = { left = "",  right = ""  }
      o.component_separators = { left = "|", right = "|" }
    else
      o.section_separators   = { left = "", right = "" }
      o.component_separators = { left = "╲", right = "╱" }

      -- o.section_separators   = { left = "", right = "" }
      -- o.component_separators = { left = "", right = "" }
    end

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
    pcall(vim.api.nvim_del_user_command, "WindowsDisableAutowidth")
    pcall(vim.api.nvim_del_user_command, "WindowsEnableAutowidth")
    pcall(vim.api.nvim_del_user_command, "WindowsEqualize")
    pcall(vim.api.nvim_del_user_command, "WindowsMaximize")
    pcall(vim.api.nvim_del_user_command, "WindowsMaximizeHorizontally")
    pcall(vim.api.nvim_del_user_command, "WindowsMaximizeVertically")
    pcall(vim.api.nvim_del_user_command, "WindowsMaximizeVerticaly")
    pcall(vim.api.nvim_del_user_command, "WindowsToggleAutowidth")
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

-- COMMENTS --

plug{
  github("numToStr/Comment.nvim"),
  setup = prequire_wrap("Comment", function(comment)
    require("Comment.utils").catch = pcall
    comment.setup{ ignore = "^$" }
  end)
}

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

plug{
  github("nvim-treesitter/nvim-treesitter"),
  -- tag = "v*",
  branch = "master",
  build = function(_)
    if vim.fn.exists("TSUpdate") ~= 0 then
      require("nvim-treesitter.configs").setup{ ensure_installed = ts_extensions }
    else
      vim.cmd.TSUpdate()
    end
  end,
  setup = prequire_wrap("nvim-treesitter", function(_)
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


----- ----- ----- ----- ----- X ----- ----- ----- ----- -----


runtimepath()

for _, name in ipairs(PLUGS_ORDER) do
  local s = PLUGS[name].setup
  if s then s() end
end
