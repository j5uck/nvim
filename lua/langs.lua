local promisify_wrap, fs, git, notify, list, prequire, sh = (function()
  local _ = require("_")
  return _.promisify_wrap, _.fs, _.git, _.notify, _.list, _.prequire, _.sh
end)()

local T_GRAY  = "\x1B[1;30m"
local T_RESET = "\x1B[0m"

local build = { cwd = vim.fn.getcwd() }

function build:cmd(cmd)
  io.stdout:write(T_GRAY .. ">>" .. T_RESET .. " "  .. list.join(cmd, " ") .. "\n")

  local job = vim.fn.jobstart(cmd, { cwd = self.cwd, on_stdout = function(_, strings, _)
    if #strings == 1 then return end
    io.stdout:write(list.join(strings, "\n"))
  end, on_stderr = function(_, strings, _)
    if #strings == 1 then return end
    io.stderr:write(list.join(strings, "\n"))
  end })

  return vim.fn.jobwait{job}[1] == 0 and self or os.exit(1)
end

function build:cd(dir)
  io.stdout:write(T_GRAY .. ">>" .. T_RESET .. " cd " .. dir .. "\n")
  if vim.fn.isabsolutepath(dir) == 1 then
    self.cwd = dir
  else
    self.cwd = vim.fs.normalize(self.cwd .. "/" .. dir)
  end
  if vim.fn.isdirectory(self.cwd) == 0 then
    vim.fn.mkdir(dir, "p")
  end
  return self
end

if not _G.arg[0] then -- :help -l
  prequire("nvim-web-devicons", function(devicons)
    return devicons.has_loaded() or devicons.setup()
  end)
end

local M = {
  c      = { name = "C",      icon = "", hl = "DevIconC" },
  bun    = { name = "Bun",    icon = "", hl = "DevIconBunLockfile" },
  sqlite = { name = "SQLite", icon = "", hl = "DevIconSql" },
  java   = { name = "Java",   icon = "", hl = "DevIconJava" },
  kotlin = { name = "Kotlin", icon = "", hl = "DevIconKotlin" },
  lua    = { name = "Lua",    icon = "", hl = "DevIconLua" },
}

for i, l in ipairs{ "c", "bun", "sqlite", "java", "kotlin", "lua" } do
  M[i] = M[l]
end

local MESSAGE = "Hello World!"

local gitignore = {
  "**/.env",
  "",
  "**/bin/",
  "**/build/",
  "**/dist/",
  "**/node_modules/",
  "",
  "**/.idea/",
  "**/.vim/",
  "**/.vscode/",
  "",
  "**/*.lock",
  "**/*-lock.json",
  "**/.~lock.*",
  "",
  "**/.DS_Store",
  "**/._*",
  "**/Thumbs.db",
  "**/desktop.ini"
}
local tsconfig_json = {
  "{",
  "  \"compilerOptions\": {",
  "    \"module\": \"nodenext\",",
  "    \"moduleResolution\": \"nodenext\",",
  "    \"esModuleInterop\": true,",
  "    \"paths\": {",
  "      \"@/*\": [ \"./src/*\" ]",
  "    },",
  "    \"lib\": [",
  "      \"dom\",",
  "      \"WebWorker\",",
  "      \"ESNext\"",
  "    ],",
  "    \"strict\": true,",
  "    \"skipLibCheck\": true,",
  "    \"noFallthroughCasesInSwitch\": true,",
  "    \"noEmit\": true,",
  "    \"allowImportingTsExtensions\": true,",
  "    \"removeComments\": true",
  "  }",
  "}"
}

M.c.init = { "src/main.c" }
M.c.code = {}
M.c.code["src/main.c"] = {
  "#include <stdio.h>",
  "",
  "int main(int argc, char *argv[]){",
  "  printf(\"%s\\n\", \"" .. MESSAGE .. "\");",
  "",
  "  return 0;",
  "}"
}
M.c.code["build.lua"] = {
  "#!/bin/nvim -l",
  "require(\"langs\").c.build()"
}
M.c.build = promisify_wrap(function(promise)
  build
    :cmd({ vim.fn.exepath("cc"), "-o", "main", "src/main.c" })
    :cmd{ "./main" }
  promise:resolve()
end)

M.bun.init = { "src/server.ts" }
M.bun.post = promisify_wrap(function(promise)
  sh({ "bun", "i" }, { timeout = (20 * 1000) }):finally(function(p)
    if p.code ~= 0 then notify.error(p.message) end
  end)

  git.init():await():unwrap()

  promise:resolve()
end)
M.bun.code = {}
M.bun.code["package.json"] = {
  "{",
  "  \"type\": \"module\",",
  "  \"scripts\": {",
  "    \"help\": \"bun build.ts -- help\",",
  "    \"clean\": \"bun build.ts -- clean\",",
  "    \"dev\": \"bun build.ts -- dev\",",
  "    \"web\": \"bun build.ts -- web\",",
  "    \"bin\": \"bun build.ts -- bin\"",
  "  },",
  "  \"devDependencies\": {",
  "    \"@types/bun\": \"*\"",
  "  }",
  "}"
}
M.bun.code["tsconfig.json"] = tsconfig_json
M.bun.code[".env"] = {
  "PORT=8080"
}
M.bun.code["build.ts"] = {
  "import fs from \"fs\";",
  "import { spawn } from \"child_process\";",
  "",
  "if(!Bun){",
  "  console.error(\"This code MUST be run with Bun!!!\");",
  "  process.exit(1);",
  "}",
  "",
  "const dot_env: Record<string, string> = {};",
  "(await Bun.file(\".env\").text())",
  "  .split(/[\\r\\n]+/)",
  "  .filter(s => !(/^ *$/.test(s) || /^ *#/.test(s)))",
  "  .forEach(s => {",
  "    const [ _, key, value] = s.trim().split(/^([^=]+)=/);",
  "    dot_env[key] = value",
  "      .replace(/\\$[\\w_]+/g, v => dot_env[v.substring(1)])",
  "      .replace(/\\${[\\w_]+}/g, v => dot_env[v.substring(2, s.length - 1)]);",
  "  });",
  "",
  "function sh(cmd: string[], env?: Record<string, string>): Promise<void>{",
  "  return new Promise((resolve, reject) => {",
  "    spawn(cmd[0], cmd.slice(1), { stdio : \"inherit\", env: { ...process.env, ...dot_env, ...(env || {}) } })",
  "      .on(\"exit\", (code: number) => code === 0 ? resolve() : reject(code))",
  "  });",
  "}",
  "",
  "const ENTRYPOINT = \"src/server.ts\";",
  "const OUTDIR = \"build/\";",
  "",
  "const plugins: Bun.BunPlugin[] = [{",
  "  name: \"HTML Minifier\",",
  "  setup(build) {",
  "    build.onLoad({ filter: /\\.html$/ }, async ({ loader, path }) =>",
  "      ({ loader, contents: (await Bun.file(path).text()).replace(/[\\s\\t]*[\\r\\n]+[\\s\\t]*/g, \"\") })",
  "    );",
  "  }",
  "}];",
  "// TODO: WASM plugin",
  "",
  "const ACTIONS: Record<string, () => Promise<void>> = {};",
  "",
  "ACTIONS.HELP = async () => {",
  "  process.stderr.write(\"Commands: \" + Object.keys(ACTIONS).sort().join(\", \").toLowerCase() + \"\\n\");",
  "};",
  "",
  "ACTIONS.CLEAN = async () => {",
  "  try{",
  "    fs.rmSync(OUTDIR, { recursive: true });",
  "  }catch(e){ }",
  "};",
  "",
  "ACTIONS.DEV = async () => {",
  "  await sh([ \"bun\", \"--bun\", ENTRYPOINT, \"--\", ...process.argv.slice(3) ], { NODE_ENV: \"DEV\" });",
  "};",
  "",
  "ACTIONS.WEB = async () => {",
  "  await ACTIONS.CLEAN();",
  "  await Bun.build({",
  "    entrypoints: [ ENTRYPOINT ],",
  "    outdir: OUTDIR,",
  "    minify: true,",
  "    target: \"bun\",",
  "    plugins,",
  "    env: \"inline\",",
  "    define: { \"process.env.NODE_ENV\": JSON.stringify(\"WEB\") }",
  "  });",
  "  await sh([ \"bun\", \"--bun\", OUTDIR + \"server.js\", \"--\", ...process.argv.slice(3) ]);",
  "};",
  "",
  "ACTIONS.BIN = async () => {",
  "  await ACTIONS.CLEAN();",
  "  await Bun.build({",
  "    entrypoints: [ ENTRYPOINT ],",
  "    compile: { outfile: OUTDIR + \"server\" },",
  "    minify: true,",
  "    target: \"bun\",",
  "    plugins,",
  "    env: \"inline\",",
  "    define: { \"process.env.NODE_ENV\": JSON.stringify(\"BIN\") }",
  "  });",
  "  await sh([ OUTDIR + \"server\", ...process.argv.slice(3) ]);",
  "};",
  "",
  "if(!process.argv[2] || !ACTIONS[process.argv[2].toUpperCase()]){",
  "  await ACTIONS.HELP();",
  "  process.exit(1);",
  "}",
  "",
  "try{",
  "  await ACTIONS[process.argv[2].toUpperCase()]();",
  "}catch(e: any){",
  "  if(typeof(e) === \"number\")",
  "    process.exit(e);",
  "  else",
  "    throw e;",
  "}"
}
M.bun.code["src/server.ts"] = {
  "import net from \"net\";",
  "import path from \"path\";",
  "import { spawn } from \"child_process\";",
  "",
  "import index from \"@/view/index.html\";",
  "",
  "import * as T from \"@/terminal.ts\";",
  "",
  "process.on(\"SIGINT\", () => {",
  "  process.exit(0);",
  "});",
  "",
  "if(process.env.NODE_ENV === \"WEB\"){",
  "  if(!Bun){",
  "    console.error(\"This code MUST be run with Bun!!!\");",
  "    process.exit(1);",
  "  }",
  "  process.chdir(path.dirname(import.meta.path));",
  "}",
  "",
  "let PORT = parseInt(process.env.PORT as string);",
  "if(process.env.NODE_ENV === \"DEV\"){",
  "  while(true){",
  "    try {",
  "      await new Promise<void>((resolve, reject) => {",
  "        var server = net.createServer();",
  "        server.once(\"listening\", () => { server.close(); resolve(); });",
  "        server.once(\"error\", e => { server.close(); reject(e); });",
  "        server.listen(PORT);",
  "      });",
  "      break;",
  "    } catch (e: any) {",
  "      if(e.code !== \"EADDRINUSE\")",
  "        throw e;",
  "      ++PORT;",
  "    }",
  "  }",
  "}",
  "",
  "// https://bun.com/docs/runtime/http/server",
  "const server: Bun.Server<undefined> = Bun.serve({",
  "  port: PORT,",
  "  routes: {",
  "    \"/\": index,",
  "    \"/*\": Response.json({ message: \"Not found\" }, { status: 404 })",
  "  }",
  "});",
  "",
  "const url = \"http://localhost:\" + server.port + \"/\";",
  "",
  "const _TAG = process.env.NODE_ENV === \"DEV\" ?",
  "    (T.BG_BLUE + T.FG_WHITE + \" DEV \" + T.RESET) :",
  "    (T.BG_GREY + T.FG_WHITE + \" PRODUCTION \" + T.RESET);",
  "",
  "const banner = \"\" +",
  "  _TAG + \" \" + T.FG_BLUE + \"Bun v\" + Bun.version + T.RESET + \"\\n\" +",
  "  \"\\n\" +",
  "  T.FG_BLUE + \"➜ \" + T.RESET + T.FG_CYAN_DARK + url + T.RESET + \"\\n\" +",
  "\"\";",
  "",
  "const shortcuts = \"\" +",
  "  \"  →   \" + T.FG_CYAN_DARK + \"c\" + T.RESET + \" + \" + T.FG_CYAN_DARK + \"<Enter>\" + T.RESET + \"   clean screen\" + \"\\n\" +",
  "  \"  →   \" + T.FG_CYAN_DARK + \"h\" + T.RESET + \" + \" + T.FG_CYAN_DARK + \"<Enter>\" + T.RESET + \"   show this help\" + \"\\n\" +",
  "  \"  →   \" + T.FG_CYAN_DARK + \"o\" + T.RESET + \" + \" + T.FG_CYAN_DARK + \"<Enter>\" + T.RESET + \"   open in browser\" + \"\\n\" +",
  "  \"  →   \" + T.FG_CYAN_DARK + \"q\" + T.RESET + \" + \" + T.FG_CYAN_DARK + \"<Enter>\" + T.RESET + \"   quit\" + \"\\n\" +",
  "\"\";",
  "",
  "process.stdout.write(",
  "  banner +",
  "  \"\\n\" +",
  "  \"Press \" + T.FG_CYAN_DARK + \"h\" + T.RESET + \" + \" + T.FG_CYAN_DARK + \"<Enter>\" + T.RESET + \" to show shortcuts\" + \"\\n\" +",
  "  \"\"",
  ");",
  "",
  "for await (const line of console) {",
  "  switch(line.toLowerCase()){",
  "    case \"h\":",
  "      process.stdout.write(",
  "        T.CLEAN +",
  "        banner +",
  "        \"\\n\" +",
  "        \"  Shortcuts:\" + \"\\n\" +",
  "        \"\\n\" +",
  "        shortcuts +",
  "        \"\\n\" +",
  "        \"\"",
  "      );",
  "      break;",
  "",
  "    case \"c\":",
  "      process.stdout.write(",
  "        T.CLEAN +",
  "        banner +",
  "        \"\\n\" +",
  "        \"\"",
  "      );",
  "      break;",
  "",
  "    case \"o\":",
  "      try {",
  "        if(process.platform === \"win32\"){",
  "          spawn(\"rundll32\", [ \"url.dll,FileProtocolHandler\", url ], { detached: true });",
  "        }else if(process.platform === \"darwin\"){",
  "          spawn(\"open\", [ url ], { detached: true });",
  "        }else{",
  "          spawn(\"xdg-open\", [ url ], { detached: true });",
  "        }",
  "      } catch (error: any) {",
  "        console.error(error);",
  "      }",
  "      break;",
  "",
  "    case \"q\":",
  "      process.exit(0);",
  "",
  "    default:",
  "      break;",
  "  }",
  "}"
}
M.bun.code["src/terminal.ts"] = {
  "export const CLEAN: string = \"\\x1B[H\\x1B[2J\";",
  "export const RESET: string = \"\\x1B[0m\";",
  "",
  "// COLOR BACKGROUND //",
  "export const BG_BLUE = \"\\x1B[1;44m\";",
  "export const BG_GREY = \"\\x1B[48;2;128;128;128m\";",
  "",
  "// COLOR FOREGROUND //",
  "export const FG_BLUE = \"\\x1B[1;34m\";",
  "export const FG_CYAN_DARK = \"\\x1B[38;2;0;206;206m\";",
  "export const FG_WHITE = \"\\x1B[1;37m\";"
}
M.bun.code["src/view/index.html"] = {
  "<!DOCTYPE html>",
  "<html lang=\"en\">",
  "  <head>",
  "    <meta charset=\"UTF-8\">",
  "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
  "    <title>" .. MESSAGE .. "</title>",
  "    <style>html, body { background-color: #222222; }</style>",
  "    <script lang=\"ts\" type=\"module\" src=\"script.ts\"></script>",
  "  </head>",
  "  <body></body>",
  "</html>"
}
M.bun.code["src/view/script.ts"] = {
  "import \"@/view/style.css\";",
  "",
  "const message = document.createElement(\"div\");",
  "message.innerText = \"" .. MESSAGE .. "\";",
  "message.classList.add(\"message\");",
  "",
  "document.body.append(message);"
}
M.bun.code["src/view/style.css"] = {
  "* {",
  "  margin: 0;",
  "  padding: 0;",
  "  box-sizing: border-box;",
  "}",
  "",
  "html, body {",
  "  width: 100%;",
  "  height: 100%;",
  "}",
  "",
  ".message {",
  "  height: 100%;",
  "",
  "  color: #FFF;",
  "  font-size: 5em;",
  "",
  "  display: flex;",
  "  justify-content: center;",
  "  align-items: center;",
  "}"
}
M.bun.code[".gitignore"] = gitignore

M.sqlite.init = { "script.ts" }
M.sqlite.post = promisify_wrap(function(promise)
  sh({ "bun", "i" }, { timeout = (20 * 1000) }):finally(function(p)
    if p.code ~= 0 then notify.error(p.message) end
  end)

  promise:resolve()
end)
M.sqlite.code = {}
M.sqlite.code["package.json"] = {
  "{",
  "  \"type\": \"module\",",
  "  \"scripts\": {",
  "    \"dev\": \"bun script.ts\"",
  "  },",
  "  \"devDependencies\": {",
  "    \"@types/bun\": \"*\"",
  "  }",
  "}"
}
M.sqlite.code["script.ts"] = {
  "import * as sqlite from \"bun:sqlite\";",
  "",
  "const db = new sqlite.Database(\"db.sqlite3\");",
  "",
  "process.stdout.write(\">>> \");",
  "for await (const line of console) {",
  "  try {",
  "    console.log(db.prepare(line).all());",
  "  } catch (error) {",
  "    console.error(error.toString())",
  "  }",
  "  process.stdout.write(\">>> \");",
  "}"
}
M.sqlite.code[".gitignore"] = gitignore

M.java.init = { "src/Main.java" }
M.java.code = {}
M.java.code["src/Main.java"] = {
  "package src;",
  "",
  "public class Main{",
  "  public static void main(String[] args){",
  "    System.out.println(\"" .. MESSAGE .. "\");",
  "  }",
  "}"
}
M.java.code["build.lua"] = {
  "#!/bin/nvim -l",
  "require(\"langs\").java.build()"
}
M.java.build = promisify_wrap(function(promise)
  local javas = list.uniq(list.insert(fs.find("\\.java$"):await():unwrap(), 1, "src/Main.java"))
  build
    :cmd(list.merge({ vim.fn.exepath("javac"), "-d", "build" }, javas))
    :cd("build")
    :cmd(list.merge({ vim.fn.exepath("jar"), "-cfe", "Main.jar", "src/Main" }, fs.find("\\.class$", "build"):await():unwrap()))
    :cmd{ vim.fn.exepath("java"), "-jar", "Main.jar" }
  promise:resolve()
end)

M.kotlin.init = { "src/Main.kt" }
M.kotlin.code = {}
M.kotlin.code["src/Main.kt"] = {
  "fun main() {",
  "  println(\"" .. MESSAGE .. "\")",
  "}"
}
M.kotlin.code["build.lua"] = {
  "#!/bin/nvim -l",
  "require(\"langs\").kotlin.build()"
}
M.kotlin.build = promisify_wrap(function(promise)
  local kts = list.uniq(list.insert(fs.find("\\.kt$"):await():unwrap(), 1, "src/Main.kt"))
  build
    :cmd(list.merge({ vim.fn.exepath("kotlinc"), "-Wextra", "-d", "build/Main.jar" }, kts))
    :cmd{ vim.fn.exepath("java"), "-jar", "build/Main.jar" }
  promise:resolve()
end)

M.lua.init = { "script.lua" }
M.lua.code = {}
M.lua.code["script.lua"] = {
  "vim.notify(\"" .. MESSAGE .. "\", vim.log.levels.WARN)"
}

return M
