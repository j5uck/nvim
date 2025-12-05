require("_").prequire("nvim-web-devicons", function() end)

local M = {
  new        = { icon = " ", hl = nil },
  c          = { icon = "", hl = "DevIconC" },
  npm        = { icon = "", hl = "DevIconPackageJson" },
  java       = { icon = "", hl = "DevIconJava" },
  kotlin     = { icon = "", hl = "DevIconKotlin" },
  lua        = { icon = "", hl = "DevIconLua" },
}

local MESSAGE = "Hello World!"

M.new.init = { "new.txt" }
M.new.code = {}

M.c.init = { "main.c" }
M.c.code = {}
M.c.code["main.c"] = {
  "// cc -o main ./main.c && ./main",
  "#include <stdio.h>",
  "",
  "int main(int argc, char *argv[]){",
  "  printf(\"%s\\n\", \"" .. MESSAGE .. "\");",
  "",
  "  return 0;",
  "}"
}

M.npm.init = { "src/server.js" }
M.npm.code = {}
M.npm.code["package.json"] = {
  "{",
  "  \"name\": \"demo\",",
  "  \"version\": \"0.0.0\",",
  "  \"scripts\": { ",
  "    \"dev\": \"bun run ./src/server.js\",",
  "    \"node\": \"node --disable-warning=ExperimentalWarning ./src/server.js\"",
  "    \"watch\": \"bun --watch run ./src/server.js\",",
  "  },",
  "  \"type\": \"module\",",
  "  \"devDependencies\": {",
  "    \"@types/bun\": \"*\",",
  "    \"@types/node\": \"*\"",
  "  }",
  "}"
}
M.npm.code["src/server.js"] = {
  "// npm run dev",
  "",
  "(async () => {",
  "  console.log(\"" .. MESSAGE .. "\");",
  "})();"
}

M.java.init = { "src/Main.java" }
M.java.code = {}
M.java.code["src/Main.java"] = {
  "// nvim -l build.lua",
  "package src;",
  "",
  "public class Main{",
  "  public static void main(String[] args){",
  "    System.out.println(\"" .. MESSAGE .. "\");",
  "  }",
  "}"
}
M.java.code["build.lua"] = {
  "local find = require(\"_\").fs.find",
  "",
  "require(\"run\"):new()",
  "  :cmd(vim.list_extend({ \"javac\", \"-d\", \"build\", \"src/Main.java\" }, find(\"\\\\.java$\")))",
  "  :cd(\"build\")",
  "  :cmd(vim.list_extend({ \"jar\", \"-cfe\", \"Main.jar\", \"src/Main\" }, find(\"\\\\.class$\", \"build\")))",
  "  :cmd{ \"java\", \"-jar\", \"Main.jar\" }"
}

M.kotlin.init = { "Main.kt" }
M.kotlin.code = {}
M.kotlin.code["Main.kt"] = {
  "// kotlinc -d Main.jar Main.kt && java -jar ./Main.jar",
  "",
  "fun main() {",
  "  println(\"" .. MESSAGE .. "\")",
  "}"
}

M.lua.init = { "script.lua" }
M.lua.code = {}
M.lua.code["script.lua"] = {
  "vim.notify(\"" .. MESSAGE .. "\", vim.log.levels.WARN)"
}

return M
