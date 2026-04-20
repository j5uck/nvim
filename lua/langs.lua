local async_wrap, await, fs, list, prequire = (function()
  local _ = require("_")
  return _.async_wrap, _.await, _.fs, _.list, _.prequire
end)()

local T_GRAY  = "\x1b[1;30m"
local T_RESET = "\x1b[0m"

local build = { cwd = vim.fn.getcwd() }

function build:cmd(cmd)
  io.stdout:write(T_GRAY .. ">>" .. T_RESET .. " "  .. table.concat(cmd, " ") .. "\n")

  local job = vim.fn.jobstart(cmd, { cwd = self.cwd, on_stdout = function(_, strings, _)
    if #strings == 1 then return end
    io.stdout:write(table.concat(strings, "\n"))
  end, on_stderr = function(_, strings, _)
    if #strings == 1 then return end
    io.stderr:write(table.concat(strings, "\n"))
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
  java   = { name = "Java",   icon = "", hl = "DevIconJava" },
  kotlin = { name = "Kotlin", icon = "", hl = "DevIconKotlin" },
  lua    = { name = "Lua",    icon = "", hl = "DevIconLua" },
}

local order = {
  "c",
  "bun",
  "java",
  "kotlin",
  "lua"
}

for i, l in ipairs(order) do
  M[i] = M[l]
end

local MESSAGE = "Hello World!"

local gitignore = {
  "**/node_modules/",
  "**/dist/",
  "**/build/",
  "**/bin/",
  "**/logs/",
  "**/.idea/",
  "**/.vim/",
  "**/.vscode/",
  "",
  "**/bun.lock",
  "**/package-lock.json",
  "",
  "**/*.lock",
  "**/.~lock.*",
  "**/*.log",
  "**/out",
  "**/desktop.ini",
  "**/Thumbs.db",
  "**/.DS_Store",
  "**/._*",
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
M.c.build = async_wrap(function(promise)
  build
    :cmd({ vim.fn.exepath("cc"), "-o", "main", "src/main.c" })
    :cmd{ "./main" }
  promise.resolve()
end)

M.bun.init = { "src/server.ts" }
M.bun.code = {}
M.bun.code["package.json"] = {
  "{",
  "  \"type\": \"module\",",
  "  \"scripts\": { ",
  "    \"clean\": \"bun build.ts -- clean\",",
  "    \"dev\": \"bun build.ts -- dev\",",
  "    \"release\": \"bun build.ts -- release\",",
  "    \"compile\": \"bun build.ts -- compile\"",
  "  },",
  "  \"devDependencies\": {",
  "    \"@types/bun\": \"*\"",
  "  }",
  "}"
}
M.bun.code["tsconfig.json"] = {
  "{",
  "  \"compilerOptions\": {",
  "    \"module\": \"nodenext\",",
  "    \"moduleResolution\": \"nodenext\",",
  "    \"esModuleInterop\": true,",
  "    \"baseUrl\": \"./\",",
  "    \"paths\": {",
  "      \"@/*\": [ \"src/*\" ]",
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
M.bun.code["build.ts"] = {
  "import fs from \"fs\";",
  "import { spawn } from \"child_process\";",
  "",
  "function $(cmd: string[]): Promise<void>{",
  "  return new Promise((resolve, reject) => {",
  "    spawn(cmd[0], cmd.slice(1), { stdio : \"inherit\" })",
  "      .on(\"exit\", (code: number) => code === 0 ? resolve() : reject(code))",
  "  });",
  "}",
  "",
  "const ENTRYPOINT = \"src/server.ts\";",
  "const OUTDIR = \"build/\";",
  "",
  "const BUN = [ \"bun\", \"--bun\" ];",
  "const BUN_BUILD = [ ...BUN, \"build\", \"--minify\", \"--production\" ];",
  "",
  "const ACTIONS: Record<string, Function> = {};",
  "",
  "ACTIONS.CLEAN = async () => {",
  "   try{",
  "     fs.rmSync(OUTDIR, { recursive: true });",
  "   }catch(e){ }",
  "};",
  "",
  "ACTIONS.DEV = async () => {",
  "  await $([ ...BUN, ENTRYPOINT, \"--\", ...process.argv.slice(3) ]);",
  "};",
  "",
  "ACTIONS.RELEASE = async () => {",
  "  await ACTIONS.CLEAN();",
  "  await $([ ...BUN_BUILD, \"--outdir\", OUTDIR, \"--target\", \"bun\", ENTRYPOINT, \"--env=inline\" ]);",
  "  await $([ ...BUN, \"--bun\", OUTDIR + \"server.js\", \"--\", ...process.argv.slice(3) ]);",
  "};",
  "",
  "ACTIONS.COMPILE = async () => {",
  "  await ACTIONS.CLEAN();",
  "  await $([ ...BUN_BUILD, \"--compile\", \"--outfile\", OUTDIR + \"server\", \"--target\", \"bun\", ENTRYPOINT, \"--env=inline\" ]);",
  "  await $([ OUTDIR + \"server\", ...process.argv.slice(3) ]);",
  "};",
  "",
  "if(!process.argv[2] || !ACTIONS[process.argv[2].toUpperCase()]){",
  "  process.stderr.write(",
  "    \"Commands:\" + \"\\n\"",
  "  );",
  "  Object.keys(ACTIONS).forEach((a: string) => {",
  "    process.stderr.write(",
  "      \"  \" + a.toLowerCase() + \"\\n\"",
  "    );",
  "  });",
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
  "import path from \"path\";",
  "import { spawn } from \"child_process\";",
  "",
  "import index from \"@/index.html\";",
  "",
  "import * as T from \"@/terminal.ts\";",
  "",
  "process.on(\"SIGINT\", () => {",
  "  process.exit(0);",
  "});",
  "",
  "if(process.env.npm_lifecycle_event === \"release\"){",
  "  process.chdir(path.dirname(import.meta.path));",
  "}",
  "",
  "const PORT = 8080;",
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
  "function getBanner(): string {",
  "  const TAG = process.env.npm_lifecycle_event === \"dev\" ?",
  "    (T.BG_BLUE + T.FG_WHITE + \" DEV \" + T.RESET) :",
  "    (T.BG_GREY + T.FG_WHITE + \" PRODUCTION \" + T.RESET);",
  "",
  "  return \"\" +",
  "    TAG + \" \" + T.FG_BLUE + \"Bun v\" + Bun.version + T.RESET + \"\\n\" +",
  "    \"\\n\" +",
  "    T.FG_BLUE + \"➜ \" + T.RESET + T.FG_CYAN_DARK + url + T.RESET + \"\\n\" +",
  "  \"\";",
  "}",
  "",
  "function getShortcuts(): string {",
  "  return \"\" +",
  "    \"  →   \" + T.FG_CYAN_DARK + \"c\" + T.RESET + \" + \" + T.FG_CYAN_DARK + \"<Enter>\" + T.RESET + \"   clear screen\" + \"\\n\" +",
  "    \"  →   \" + T.FG_CYAN_DARK + \"h\" + T.RESET + \" + \" + T.FG_CYAN_DARK + \"<Enter>\" + T.RESET + \"   show this help\" + \"\\n\" +",
  "    \"  →   \" + T.FG_CYAN_DARK + \"o\" + T.RESET + \" + \" + T.FG_CYAN_DARK + \"<Enter>\" + T.RESET + \"   open in browser\" + \"\\n\" +",
  "    \"  →   \" + T.FG_CYAN_DARK + \"q\" + T.RESET + \" + \" + T.FG_CYAN_DARK + \"<Enter>\" + T.RESET + \"   quit\" + \"\\n\" +",
  "  \"\";",
  "}",
  "",
  "process.stdout.write(",
  "  getBanner() +",
  "  \"\\n\" +",
  "  \"Press \" + T.FG_CYAN_DARK + \"h\" + T.RESET + \" + \" + T.FG_CYAN_DARK + \"<Enter>\" + T.RESET + \" to show shortcuts\" + \"\\n\" +",
  "  \"\"",
  ");",
  "",
  "for await (const line of console) {",
  "  switch(line){",
  "    case \"h\":",
  "      process.stdout.write(",
  "        T.CLEAR +",
  "        getBanner() +",
  "        \"\\n\" +",
  "        \"  Shortcuts:\" + \"\\n\" +",
  "        \"\\n\" +",
  "        getShortcuts() +",
  "        \"\\n\" +",
  "        \"\"",
  "      );",
  "      break;",
  "",
  "    case \"c\":",
  "      process.stdout.write(",
  "        T.CLEAR +",
  "        getBanner() +",
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
  "export const CLEAR: string = \"\\x1b[H\\x1b[2J\";",
  "export const RESET: string = \"\\x1b[0m\";",
  "",
  "// COLOR BACKGROUND //",
  "export const BG_BLUE = \"\\x1b[1;44m\";",
  "export const BG_GREY = \"\\x1b[48;2;128;128;128m\";",
  "",
  "// COLOR FOREGROUND //",
  "export const FG_BLUE = \"\\x1b[1;34m\";",
  "export const FG_CYAN_DARK = \"\\x1b[38;2;0;206;206m\";",
  "export const FG_WHITE = \"\\x1b[1;37m\";"
}
M.bun.code["src/index.html"] = {
  "<!DOCTYPE html>",
  "<html lang=\"en\">",
  "  <head>",
  "    <meta charset=\"UTF-8\">",
  "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
  "    <title>" .. MESSAGE .. "</title>",
  "    <style>html, body { background-color: #222222; }</style>",
  "    <link href=\"style/global.css\" rel=\"stylesheet\">",
  "    <script lang=\"ts\" type=\"module\" src=\"index.ts\"></script>",
  "  </head>",
  "  <body></body>",
  "</html>"
}
M.bun.code["src/index.ts"] = {
  "const body: HTMLElement = document.body;",
  "",
  "const message = document.createElement(\"div\");",
  "message.innerText = \"" .. MESSAGE .. "\";",
  "",
  "message.style.height = \"100%\";",
  "",
  "message.style.color = \"white\";",
  "message.style.fontSize = \"5em\";",
  "",
  "message.style.display = \"flex\";",
  "message.style.justifyContent = \"center\";",
  "message.style.alignItems = \"center\";",
  "",
  "body.append(message);",
}
M.bun.code["src/style/global.css"] = {
  "* {",
  "  margin: 0;",
  "  padding: 0;",
  "  box-sizing: border-box;",
  "}",
  "",
  "html, body {",
  "  width: 100%;",
  "  height: 100%;",
  "}"
}
M.bun.code[".gitignore"] = gitignore

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
M.java.build = async_wrap(function(promise)
  local javas = list.uniq(list.insert(await(fs.find("\\.java$")).unwrap(), 1, "src/Main.java"))
  build
    :cmd(list.merge({ vim.fn.exepath("javac"), "-d", "build" }, javas))
    :cd("build")
    :cmd(list.merge({ vim.fn.exepath("jar"), "-cfe", "Main.jar", "src/Main" }, await(fs.find("\\.class$", "build")).unwrap()))
    :cmd{ vim.fn.exepath("java"), "-jar", "Main.jar" }
  promise.resolve()
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
M.kotlin.build = async_wrap(function(promise)
  local kts = list.uniq(list.insert(await(fs.find("\\.kt$")).unwrap(), 1, "src/Main.kt"))
  build
    :cmd(list.merge({ vim.fn.exepath("kotlinc"), "-Wextra", "-d", "build/Main.jar" }, kts))
    :cmd{ vim.fn.exepath("java"), "-jar", "build/Main.jar" }
  promise.resolve()
end)

M.lua.init = { "script.lua" }
M.lua.code = {}
M.lua.code["script.lua"] = {
  "vim.notify(\"" .. MESSAGE .. "\", vim.log.levels.WARN)"
}

return M
