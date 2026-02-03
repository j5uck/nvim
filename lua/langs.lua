local find, prequire = (function()
  local _ = require("_")
  return _.find, _.prequire
end)()

local runner = require("run")

if not _G.arg[0] then -- :help -l
  prequire("nvim-web-devicons", function() end)
end

local M = {
  new    = { name = "NEW",    icon = " ", hl = nil },
  c      = { name = "C",      icon = "", hl = "DevIconC" },
  npm    = { name = "NPM",    icon = "", hl = "DevIconPackageJson" },
  react  = { name = "React",  icon = "", hl = "DevIconTsx" },
  java   = { name = "Java",   icon = "", hl = "DevIconJava" },
  kotlin = { name = "Kotlin", icon = "", hl = "DevIconKotlin" },
  lua    = { name = "Lua",    icon = "", hl = "DevIconLua" },
}

local function sort()
  M[1] = M["new"]
  M[2] = M["c"]
  M[3] = M["npm"]
  M[4] = M["react"]
  M[5] = M["java"]
  M[6] = M["kotlin"]
  M[7] = M["lua"]
end

local MESSAGE = "Hello World!"

local gitignore = {
  "**/node_modules/",
  "**/dist/",
  "**/build/",
  "**/logs/",
  "**/.idea/",
  "**/.vscode/",
  "",
  "**/package-lock.json",
  "**/*.lock",
  "**/*.log",
  "**/out",
  "**/.DS_Store",
  "**/._*",
}

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
  "  \"type\": \"module\",",
  "  \"scripts\": { ",
  "    \"bun\": \"bun run ./src/server.js\",",
  "    \"node\": \"node --disable-warning=ExperimentalWarning ./src/server.js\",",
  "    \"watch\": \"bun --watch run ./src/server.js\"",
  "  },",
  "  \"devDependencies\": {",
  "    \"@types/bun\": \"*\",",
  "    \"@types/node\": \"*\"",
  "  }",
  "}"
}
M.npm.code["src/server.js"] = {
  "// npm run bun",
  "",
  "(async () => {",
  "  console.log(\"" .. MESSAGE .. "\");",
  "})();"
}
M.npm.code[".gitignore"] = gitignore

M.react.init = { "src/script.tsx" }
M.react.code = {}
M.react.code["src/script.tsx"] = {
  "import \"./style.css\";",
  "",
  "import { scan } from \"react-scan\";",
  "import React from \"react\";",
  "import { StrictMode } from \"react\";",
  "import { createRoot } from \"react-dom/client\";",
  "",
  "import { Message } from \"./Message\";",
  "",
  "scan({ enabled: true, });",
  "",
  "createRoot(document.getElementById(\"root\")!)",
  "  .render(<StrictMode><Message message=\"" .. MESSAGE .. "\"/></StrictMode>);"
}
M.react.code["src/Message.tsx"] = {
  "import React from \"react\";",
  "",
  "export function Message(props: { message: string }) {",
  "  return <div id=\"message-container\">",
  "    <h1 id=\"message\">{props.message}</h1>",
  "  </div>;",
  "}"
}
M.react.code["src/index.html"] = {
  "<!DOCTYPE html>",
  "<html lang=\"en\">",
  "  <head>",
  "    <meta charset=\"UTF-8\">",
  "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
  "    <title>demo</title>",
  "  </head>",
  "  <body>",
  "    <div id=\"root\"></div>",
  "    <script type=\"module\" src=\"script.tsx\"></script>",
  "  </body>",
  "</html>"
}
M.react.code["src/style.css"] = {
  "*{",
  "  margin: 0;",
  "  padding: 0;",
  "  border: 0 solid;",
  "  box-sizing: border-box;",
  "  color: white;",
  "}",
  "",
  "html {",
  "  background-color: #242424;",
  "}",
  "",
  "#root {",
  "  height: 100vh;",
  "  width: 100vw;",
  "}",
  "",
  "#message-container {",
  "  display: flex;",
  "  justify-content: center;",
  "  align-items: center;",
  "  width: 100%;",
  "  height: 100%;",
  "}",
  "",
  "#message {",
  "  font-size: xxx-large;",
  "  text-align: center;",
  "}"
}
M.react.code["package.json"] = {
  "{",
  "  \"name\": \"demo\",",
  "  \"type\": \"module\",",
  "  \"scripts\": { ",
  "    \"build\": \"bun build --minify --outdir=build ./src/index.html\",",
  "    \"dev\": \"bun run ./src/index.html\",",
  "    \"watch\": \"bun --watch run ./src/index.html\"",
  "  },",
  "  \"dependencies\": {",
  "    \"react\": \"*\",",
  "    \"react-dom\": \"*\"",
  "  },",
  "  \"devDependencies\": {",
  "    \"@types/bun\": \"*\",",
  "    \"@types/node\": \"*\",",
  "    \"@types/react\": \"*\",",
  "    \"@types/react-dom\": \"*\",",
  "    \"react-scan\": \"*\"",
  "  }",
  "}"
}
M.react.code[".gitignore"] = gitignore

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
  "require(\"langs\").java.runner()",
}
M.java.runner = function()
  runner:new()
    :cmd(vim.list_extend({ vim.fn.exepath("javac"), "-d", "build", "src/Main.java" }, find("\\.java$")))
    :cd("build")
    :cmd(vim.list_extend({ vim.fn.exepath("jar"), "-cfe", "Main.jar", "src/Main" }, find("\\.class$", "build")))
    :cmd{ vim.fn.exepath("java"), "-jar", "Main.jar" }
end

M.kotlin.init = { "src/Main.kt" }
M.kotlin.code = {}
M.kotlin.code["src/Main.kt"] = {
  "// nvim -l build.lua",
  "",
  "fun main() {",
  "  println(\"" .. MESSAGE .. "\")",
  "}"
}
M.kotlin.code["build.lua"] = {
  "require(\"langs\").kotlin.runner()",
}
M.kotlin.runner = function()
  runner:new()
    :cmd(vim.list_extend({ vim.fn.exepath("kotlinc"), "-Wextra", "-d", "build/Main.jar", "src/Main.kt" }, find("\\.kt$")))
    :cmd{ vim.fn.exepath("java"), "-jar", "build/Main.jar" }
end

M.lua.init = { "script.lua" }
M.lua.code = {}
M.lua.code["script.lua"] = {
  "vim.notify(\"" .. MESSAGE .. "\", vim.log.levels.WARN)"
}

sort()

return M
