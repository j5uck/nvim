local MESSAGE = "Hello World!"

pcall(require, "nvim-web-devicons")
local M = {
  new        = { icon = " ", hl = nil },
  c          = { icon = "", hl = "DevIconC" },
  lua        = { icon = "", hl = "DevIconLua" },
  html       = { icon = "", hl = "DevIconHtml" },
  javascript = { icon = "", hl = "DevIconJs" },
  typescript = { icon = "", hl = "DevIconTypeScript" },
  npm        = { icon = "", hl = "DevIconPackageJson" },
  java       = { icon = "", hl = "DevIconJava" },
  kotlin     = { icon = "", hl = "DevIconKotlin" },
  python     = { icon = "", hl = "DevIconPy" },
  rust       = { icon = "", hl = "DevIconRs" },
  sh         = { icon = "", hl = "DevIconSh" },
}

M.new.init = { "notes.txt" }
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

M.lua.init = { "script.lua" }
M.lua.code = {}
M.lua.code["script.lua"] = {
  "vim.notify(\"" .. MESSAGE .. "\", vim.log.levels.WARN)"
}

M.html.init = { "index.html", "script.js" }
M.html.code = {}
M.html.code["index.html"] = {
  "<!DOCTYPE html>",
  "<html lang=\"en\">",
  "  <head>",
  "    <meta charset=\"UTF-8\">",
  "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
  "    <title></title>",
  "    <link href=\"style.css\" rel=\"stylesheet\">",
  "  </head>",
  "  <body>",
  "    <h1>" .. MESSAGE .. "</h1>",
  "  </body>",
  "  <script src=\"script.js\" fetchpriority=\"high\"></script>",
  "</html>"
}
M.html.code["style.css"] = {
  "* {",
  "  margin: 0;",
  "  padding: 0;",
  "  color: white;",
  "}",
  "",
  "html, body {",
  "  background-color: #3c3c3c;",
  "  height: 100%;",
  "  width: 100%;",
  "}",
  "",
  "h1 {",
  "  font-size: 5rem;",
  "  width: 100%;",
  "  text-align: center;",
  "}"
}
M.html.code["script.js"] = {
  "\"use strict\";",
  "",
  "(async () => {",
  "  console.log(\"" .. MESSAGE .. "\");",
  "})();"
}

M.javascript.init = { "script.js" }
M.javascript.code = {}
M.javascript.code["script.js"] = {
  "#!/bin/bun run",
  "\"use strict\";",
  "",
  "(async () => {",
  "  console.log(\"" .. MESSAGE .. "\");",
  "})();"
}

M.typescript.init = { "script.ts" }
M.typescript.code = {}
M.typescript.code["script.ts"] = {
  "#!/bin/bun run",
  "",
  "(async () => {",
  "  console.log(\"" .. MESSAGE .. "\");",
  "})();"
}

M.npm.init = { "src/server.ts" }
M.npm.code = {}
M.npm.code["package.json"] = {
  "{",
  "  \"name\": \"demo\",",
  "  \"version\": \"0.0.0\",",
  "  \"scripts\": { ",
  "    \"dev\": \"bun --watch run ./src/server.ts\",",
  "    \"release\": \"node --disable-warning=ExperimentalWarning ./src/server.ts\"",
  "  },",
  "  \"type\": \"module\",",
  "  \"devDependencies\": {",
  "    \"@types/bun\": \"*\",",
  "    \"@types/node\": \"*\"",
  "  }",
  "}"
}
M.npm.code["src/server.ts"] = {
  "// npm run dev",
  "// import { example } from \"example-package\";",
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
  "  :cmd(vim.list_extend({ \"javac\", \"-d\", \"build\", \"src/Main.java\" }, find(\"\\\\.java\")))",
  "  :cd(\"build\")",
  "  :cmd(vim.list_extend({ \"jar\", \"-cfe\", \"Main.jar\", \"src/Main\" }, find(\"\\\\.class\", \"build\")))",
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

M.python.init = { "__init__.py" }
M.python.code = {}
M.python.code["__init__.py"] = {
  "#!/bin/python",
  "",
  "print(\"" .. MESSAGE .. "\")"
}

M.rust.init = { "main.rs" }
M.rust.code = {}
M.rust.code["main.rs"] = {
  "// rustc ./main.rs && ./main",
  "",
  "fn main() {",
  "  println!(\"{}\", \"" .. MESSAGE .. "\");",
  "}"
}

M.sh.init = { "script.sh" }
M.sh.code = {}
M.sh.code["script.sh"] = {
  "#!/bin/bash",
  "echo '" .. MESSAGE .. "'"
}

return M
