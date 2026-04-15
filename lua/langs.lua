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

if #_G.arg == 0 then -- :help -l
  prequire("nvim-web-devicons", function(_) end)
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
  "    \"dev\": \"bun build.ts -- dev\",",
  "    \"clean\": \"bun build.ts -- clean\",",
  "    \"build\": \"bun build.ts -- build\",",
  "    \"compile\": \"bun build.ts -- compile\",",
  "    \"release\": \"bun build.ts -- release\"",
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
  "      .on(\"exit\", (code: number) => code === 0 ? resolve() : process.exit(code))",
  "  });",
  "}",
  "",
  "const ENTRYPOINT = \"src/server.ts\";",
  "const OUTDIR = \"build/\";",
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
  "  await $([ \"bun\", \"--bun\", ENTRYPOINT ]);",
  "};",
  "",
  "ACTIONS.BUILD = async () => {",
  "  await ACTIONS.CLEAN();",
  "  await $([ \"bun\", \"--bun\", \"build\", \"--minify\", \"--production\", \"--outdir\", OUTDIR, \"--target\", \"bun\", ENTRYPOINT ]);",
  "};",
  "",
  "ACTIONS.RELEASE = async () => {",
  "  await ACTIONS.BUILD();",
  "  await $([ \"bun\", \"--bun\", OUTDIR + \"server.js\" ]);",
  "};",
  "",
  "ACTIONS.COMPILE = async () => {",
  "  await ACTIONS.CLEAN();",
  "  await $([ \"bun\", \"--bun\", \"build\", \"--minify\", \"--production\", \"--compile\", \"--outfile\", OUTDIR + \"server\", \"--target\", \"bun\", ENTRYPOINT ]);",
  "};",
  "",
  "await ACTIONS[process.argv[2].toUpperCase()]();"
}
M.bun.code["src/server.ts"] = {
  "import index from \"@/index.html\";",
  "",
  "const PORT = 8080;",
  "",
  "// https://bun.com/docs/runtime/http/server",
  "Bun.serve({",
  "  port: PORT,",
  "  routes: {",
  "    \"/\": index,",
  "    \"/*\": Response.json({ message: \"Not found\" }, { status: 404 })",
  "  }",
  "});",
  "",
  "process.on(\"SIGINT\", () => {",
  "  process.exit(0);",
  "});",
  "",
  "console.log(\"Server running at http://localhost:\" + PORT + \"/\");"
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
  "message.innerText = \"Hello World!\";",
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
