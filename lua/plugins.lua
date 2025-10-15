local flags, notify, notify_once, prequire_wrap = (function()
  local _ = require("_")
  return _.flags, _.notify, _.notify_once, _.prequire_wrap
end)()

local joinpath = vim.fn.has("win32") == 1 and function(...)
  return ({string.gsub(vim.fs.joinpath(...), "[\\/]+", "\\")})[1]
end or function(...)
  return ({string.gsub(vim.fs.joinpath(...), "/+", "/")})[1]
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

PLUG_SYNC.start = function(args)
  if vim.fn.executable("git") == 0 then
    notify.error("Git not found\nCannot proceed")
    return
  end

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
  for _, v in ipairs{"<CR>", "x", "X", "d", "dd", "i", "I", "a", "A", "o", "O", "r", "R"} do
    vim.keymap.set("n", v, "<Nop>", { buffer = PLUG_SYNC.buf })
  end
  vim.keymap.set("n", "q", "<cmd>q<CR>", { buffer = PLUG_SYNC.buf })
  if vim.fn.exists('+colorcolumn') == 1 then
    vim.cmd[[setlocal colorcolumn=]]
  end

  PLUG_SYNC.text = {}

  local po = vim.fn.sort(#args.fargs > 0 and args.fargs or PLUGS_ORDER, "i")

  for _ = 1, #po, 1 do table.insert(PLUG_SYNC.text, "") end

  do
    if #args.fargs > 0 then goto continue end
    local len = #(joinpath(PLUG_HOME, "/"))+1

    local untracked = vim.tbl_filter(function(v)
      return PLUGS[string.sub(v,len)] == nil
    end, vim.fn.globpath(PLUG_HOME, "*", 1, true)) -- dot files are ignored

    if #untracked == 0 then goto continue end

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
    ::continue::
  end

  local function set_lines()
    vim.bo[PLUG_SYNC.buf].modifiable = true
    vim.api.nvim_buf_set_lines(PLUG_SYNC.buf, 0, -1, false, PLUG_SYNC.text)
    vim.bo[PLUG_SYNC.buf].modifiable = false
    vim.bo[PLUG_SYNC.buf].modified = false
  end

  if #po == 0 then
    PLUG_SYNC.finally()
    return
  end

  vim.cmd[[hi link PlugSyncDone Function]]

  local success = {}

  local error = false
  for i = 1, #po, 1 do
    local name = po[i]
    PLUG_SYNC.text[i] = "+ " .. name .. ": Fetching..."
    set_lines()
    PLUG_SYNC.fetch(name, PLUGS[name], function(status)
      success[name] = status
      if success[name] then
        PLUG_SYNC.text[i] = "- " .. name .. ": Fetching... Done!"
      else
        PLUG_SYNC.text[i] = "x " .. name .. ": Fetching... ERROR"
        error = true
      end
      set_lines()

      if #vim.tbl_keys(success) < #po then return end

      runtimepath()

      local po_build = vim.tbl_filter(function(v)
        return PLUGS[v].build and success[v]
      end, po)

      success = {}
      if #po_build == 0 then
        PLUG_SYNC.finally()
        return
      end
      if error then return end

      for _, name_build in ipairs(po_build) do
        PLUG_SYNC.text[i] = "x " .. name .. ": Building..."
        set_lines()
        PLUGS[name_build].build()
        PLUG_SYNC.text[i] = "- " .. name .. ": Building... Done!"
      end
      set_lines()

      PLUG_SYNC.finally()
      for _, n in ipairs(po) do
        -- vim.cmd.helptags({ joinpath(PLUG_HOME, n, "doc"), mods = { silent = true }})
        vim.cmd("silent! helptags " .. vim.fn.fnameescape(joinpath(PLUG_HOME, n, "doc")))
      end
    end)
  end
  vim.fn.cursor(1, 2)
end

PLUG_SYNC.fetch = function(name, plug, callback)
  local tasks = (vim.fn.isdirectory(joinpath(PLUG_HOME, name, ".git")) == 1) and {} or
    {{
      cmd={ "git", "clone", "--shallow-submodules", "--depth=1", "--progress", plug.uri, joinpath(PLUG_HOME, name) },
      opts={ text = true, clear_env = true }
    }}

  local function t(cmd)
    table.insert(tasks, { cmd = cmd, opts={ text = true, cwd = joinpath(PLUG_HOME, name), clear_env = true } })
  end

  if plug.commit then
    t{ "git", "fetch", "origin", "--depth=1", "--progress", plug.commit }
    t{ "git", "reset", "--hard", plug.commit }
  elseif plug.tag then
    t{ "git", "fetch", "origin", "--depth=1", "--progress", "--no-tags", "refs/tags/".. plug.tag ..":refs/tags/".. plug.tag}
    t{ "git", "tag", "--list", plug.tag, "--sort", "-version:refname"}
    t(function(o)
      return { "git", "checkout", "tags/" .. vim.fn.split(o.stdout)[1] }
    end)
  elseif plug.branch then
    t{ "git", "fetch", "origin", "--depth=1", "--progress", "+refs/heads/".. plug.branch ..":refs/remotes/origin/".. plug.branch }
    t{ "git", "checkout", "origin/"..plug.branch }
  else
    t{ "git", "fetch", "origin", "--depth=1", "--progress" }
    t{ "git", "ls-remote", "--symref", "origin", "HEAD" }
    t(function(o)
      local s = string.gsub(vim.fn.split(o.stdout)[2], ".+/(.+)$", "%1")
      return { "git", "switch", s }
    end)
  end

  if vim.fn.filereadable(joinpath(PLUG_HOME, name, ".gitmodules")) then
    t{ "git", "submodule", "update", "--init", "--recursive", "--depth=1", "--jobs=16" }
  end

  local last_command = { code = 0 }
  local function do_task(i)
    if last_command.code ~= 0 or not tasks[i] then
      callback(last_command.code == 0)
      return
    end

    local cmd = type(tasks[i].cmd) == "function" and tasks[i].cmd(last_command) or tasks[i].cmd

    vim.system(cmd, tasks[i].opts, vim.schedule_wrap(function(o)
      if o.code ~= 0 then
        notify.error("\"" .. name .. "\" exit status: " .. o.code .. "\n\n" .. o.stderr)
      end

      last_command = o
      do_task(i+1)
    end))
  end
  do_task(1)
end

PLUG_SYNC.finally = function()
  vim.cmd[[hi link PlugSyncDone Label]]
  local n = string.format("%.3f", vim.trim(vim.fn.reltimestr(vim.fn.reltime(PLUG_SYNC.reltime))))
  notify.warn("[LUA-PLUG] Elapsed time: " .. n .. " seconds")
end

vim.api.nvim_create_user_command("PlugSync", PLUG_SYNC.start, {
  complete = function(search)
    return vim.fn.sort(vim.tbl_filter(function(name)
      return vim.fn.match(name, search) == 0
    end, PLUGS_ORDER), "i")
  end,
  nargs = "*",
  bang = true
})

local function plug(plugin)
  local name = plugin.as or string.gsub(plugin[1], ".+/(.+)%.git$", "%1")

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
  github("sainnhe/sonokai"),
  tag = "*",
  setup = function()
    vim.g.sonokai_disable_terminal_colors = 1
  end
}

plug{ github("rebelot/kanagawa.nvim") }

plug{
  github("folke/tokyonight.nvim"),
  tag = "stable",
  build = function() vim.cmd[[silent! colorscheme tokyonight-storm]] end,
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
      -- debug=true,
      lsp = {
        override = {
          -- ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          -- ["vim.lsp.util.stylize_markdown"] = true
        },
      },
      presets = {
        command_palette = true,
        long_message_to_split = false,
      },
      throttle = 1000 / FPS
    }
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
    colorizer.setup(
      -- { "css", "javascript", "html" }
      -- or
      nil,
      {
        RGB      = true,
        RRGGBB   = true,
        names    = true,
        RRGGBBAA = true,
        -- rgb_fn   = false,
        -- hsl_fn   = false,
        -- css      = false,
        -- css_fn   = false,
        xterm    = true,
        mode     = "background"
      }
    )
  end)
}

-- MARKDOWN PREVIEW --

plug{
  github("iamcco/markdown-preview.nvim"),
  build = function()
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

    ll("help", { fn("NEOVIM HELP")  }, { nil, PROGRESS, LOCATION })
    ll("checkhealth", { fn("CHECK HEALTH") }, { nil, PROGRESS, LOCATION })
    ll("TelescopePrompt", { fn("TELESCOPE") })
    ll("undotree", { fn("UNDOTREE"), nil, function()
      local n = vim.api.nvim_buf_get_name(vim.t.undotree.b.target)
      if #n == 0 then return "[No Name]" end
      return vim.fs.basename(n)
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
    if (vim.fn.has("win32") == 0) and vim.fn.readfile("/etc/hostname")[1] == "host7" then
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
  end)
}

-- AUTO CLOSE TAGS --

plug{
  github("alvan/vim-closetag"),
  setup = function()
    vim.g.closetag_filenames = "*.html,*.xhtml,*.phtml"
    vim.g.closetag_xhtml_filenames = "*.xhtml,*.jsx"
  end
}

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
  tag = "v*",
  build = function()
    if #vim.fn.getcompletion("TSUpdate", "command") == 0 then
      require("nvim-treesitter.configs").setup{ ensure_installed = ts_extensions }
    else
      vim.cmd.TSUpdate()
    end
  end,
  setup = prequire_wrap("nvim-treesitter", function()
    require("nvim-treesitter.configs").setup{
      --sync_install = true,
        ensure_installed = ts_extensions,
        highlight = {
          enable = true,
          -- disable = function(lang, buf) return true end,
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
  build = function()
    local coc = require("coc")

    if #vim.fn.getcompletion("CocUpdate", "command") == 0 then
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
    vim.api.nvim_create_user_command("CocStop", vim.fn["coc#rpc#stop"], {})

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
