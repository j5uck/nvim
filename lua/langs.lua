local prequire = (function()
  local _ = require("_")
  return _.prequire
end)()

if not _G.arg[0] then -- :help -l
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
M.c.runner = {
  "runner",
  "  :cmd({ vim.fn.exepath(\"cc\"), \"-o\", \"main\", \"src/main.c\" })",
  "  :cmd{ \"./main\" }"
}

M.bun.init = { "src/server.js" }
M.bun.code = {}
M.bun.code["package.json"] = {
  "{",
  "  \"type\": \"module\",",
  "  \"scripts\": { ",
  "    \"dev\": \"bun --bun ./src/server.js\",",
  "    \"watch\": \"bun --bun --watch ./src/server.js\"",
  "  },",
  "  \"devDependencies\": {",
  "    \"@types/bun\": \"*\"",
  "  }",
  "}"
}
M.bun.code["src/server.js"] = {
  "(async () => {",
  "  console.log(\"" .. MESSAGE .. "\");",
  "})();"
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
M.java.runner = {
  "runner",
  "  :cmd(vim.list_extend({ vim.fn.exepath(\"javac\"), \"-d\", \"build\", \"src/Main.java\" }, fs.find(\"\\\\.java$\")))",
  "  :cd(\"build\")",
  "  :cmd(vim.list_extend({ vim.fn.exepath(\"jar\"), \"-cfe\", \"Main.jar\", \"src/Main\" }, fs.find(\"\\\\.class$\", \"build\")))",
  "  :cmd{ vim.fn.exepath(\"java\"), \"-jar\", \"Main.jar\" }"
}

M.kotlin.init = { "src/Main.kt" }
M.kotlin.code = {}
M.kotlin.code["src/Main.kt"] = {
  "fun main() {",
  "  println(\"" .. MESSAGE .. "\")",
  "}"
}
M.kotlin.runner = {
  "runner",
  "  :cmd(vim.list_extend({ vim.fn.exepath(\"kotlinc\"), \"-Wextra\", \"-d\", \"build/Main.jar\", \"src/Main.kt\" }, fs.find(\"\\\\.kt$\")))",
  "  :cmd{ vim.fn.exepath(\"java\"), \"-jar\", \"build/Main.jar\" }"
}

M.lua.init = { "script.lua" }
M.lua.code = {}
M.lua.code["script.lua"] = {
  "vim.notify(\"" .. MESSAGE .. "\", vim.log.levels.WARN)"
}

return M
