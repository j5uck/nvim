local prequire = (function()
  local _ = require("_")
  return _.prequire
end)()

if not _G.arg[0] then -- :help -l
  prequire("nvim-web-devicons", function() end)
end

local M = {
  c      = { name = "C",      icon = "", hl = "DevIconC" },
  bun    = { name = "Bun",    icon = "", hl = "DevIconBunLockfile" },
  preact = { name = "Preact", icon = "", hl = "DevIconTsx" },
  java   = { name = "Java",   icon = "", hl = "DevIconJava" },
  kotlin = { name = "Kotlin", icon = "", hl = "DevIconKotlin" },
  lua    = { name = "Lua",    icon = "", hl = "DevIconLua" },
}

local order = {
  "c",
  "bun",
  "preact",
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
--"    \"node\": \"node --disable-warning=ExperimentalWarning ./src/server.js\",",
  "    \"watch\": \"bun --bun --watch ./src/server.js\"",
  "  },",
  "  \"devDependencies\": {",
  "    \"@types/bun\": \"*\",",
  "    \"@types/node\": \"*\"",
  "  }",
  "}"
}
M.bun.code["src/server.js"] = {
  "(async () => {",
  "  console.log(\"" .. MESSAGE .. "\");",
  "})();"
}
M.bun.code[".gitignore"] = gitignore

M.preact.init = { "src/index.tsx" }
M.preact.code = {}
M.preact.code["package.json"] = {
  "{",
  "  \"type\": \"module\",",
  "  \"scripts\": {",
  "    \"dev\": \"bun --bun src/index.html\",",
  "    \"build\": \"bun build --minify --outdir=build src/index.html\"",
  "  },",
  "  \"dependencies\": {",
  "    \"preact\": \"*\",",
  "    \"preact-iso\": \"*\"",
  "  },",
  "  \"devDependencies\": {",
  "    \"@types/bun\": \"*\"",
  "  }",
  "}"
}
M.preact.code["server.js"] = {
  "\"use strict\";",
  "",
  "const http = require(\"http\");",
  "const fs = require(\"fs\");",
  "const path = require(\"path\");",
  "",
  "const PORT = process.env.PORT || 3003;",
  "const BUILD_DIR = path.join(__dirname, \"build\");",
  "",
  "const files = {};",
  "fs.readdirSync(path.join(__dirname, \"build\")).forEach(f => {",
  "  const extension = path.extname(f).toLowerCase();",
  "  const contentType = ({",
  "    \".css\":   \"text/css\",",
  "    \".gif\":   \"image/gif\",",
  "    \".html\":  \"text/html\",",
  "    \".ico\":   \"image/x-icon\",",
  "    \".jpeg\":  \"image/jpeg\",",
  "    \".jpg\":   \"image/jpeg\",",
  "    \".js\":    \"text/javascript\",",
  "    \".json\":  \"application/json\",",
  "    \".png\":   \"image/png\",",
  "    \".svg\":   \"image/svg+xml\",",
  "    \".ttf\":   \"font/ttf\",",
  "    \".woff\":  \"font/woff\",",
  "    \".woff2\": \"font/woff2\"",
  "  })[extension];",
  "",
  "  files[\"/\" + f] = {",
  "    path: path.join(BUILD_DIR, f),",
  "    contentType,",
  "  };",
  "});",
  "",
  "const server = http.createServer((req, res) => {",
  "  if(req.method !== \"GET\"){",
  "    res.writeHead(500, {});",
  "    return res.end();",
  "  }",
  "",
  "  const url = req.url.split('?')[0];",
  "  if(url === \"/.well-known/appspecific/com.chrome.devtools.json\"){",
  "    res.writeHead(404, {});",
  "    return res.end();",
  "  }",
  "",
  "  const file = files[url] || files[\"/index.html\"]",
  "",
  "  res.writeHead(200, { 'Content-Type': file.contentType });",
  "  res.end(fs.readFileSync(file.path));",
  "});",
  "",
  "server.listen(PORT, () => {",
  "  console.log(\"Server running on http://localhost:\" + PORT);",
  "});"
}
M.preact.code["tsconfig.json"] = {
  "{",
  "  \"compilerOptions\": {",
  "    \"baseUrl\": \".\",",
  "    \"paths\": {",
  "      \"@/*\": [ \"src/*\" ]",
  "    },",
  "    \"noEmit\": true,",
  "    \"allowImportingTsExtensions\": true,",
  "    \"jsx\": \"react-jsx\",",
  "    \"jsxImportSource\": \"preact\"",
  "  }",
  "}"
}
M.preact.code["src/index.html"] = {
  "<!DOCTYPE html>",
  "<html lang=\"en\">",
  "  <head>",
  "    <meta charset=\"UTF-8\"/>",
  "    <!-- <link rel=\"icon\" type=\"image/svg+xml\" href=\"assets/preact.svg\" /> -->",
  "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />",
  "    <title>Preact</title>",
  "    <style>",
  "      * {",
  "        margin: 0;",
  "        padding: 0;",
  "      }",
  "      html, body {",
  "        height: 100vh;",
  "        width: 100vw;",
  "        background-color: #333;",
  "      }",
  "    </style>",
  "    <script type=\"module\" src=\"index.tsx\"></script>",
  "  </head>",
  "</html>"
}
M.preact.code["src/index.tsx"] = {
  "import \"@/style.css\";",
  "",
  "import { render } from \"preact\";",
  "import { LocationProvider, Router, Route } from \"preact-iso\";",
  "",
  "import { Header } from \"@/components/Header.tsx\";",
  "",
  "import { Home } from \"@/pages/Home/index.tsx\";",
  "import { E404 } from \"@/pages/E404/index.tsx\";",
  "",
  "export function Index(){",
  "  return <LocationProvider>",
  "    <Header/>",
  "    <div class=\"main\">",
  "      <Router>",
  "        <Route path=\"/\" component={ Home } />",
  "        <Route default component={ E404 } />",
  "      </Router>",
  "    </div>",
  "  </LocationProvider>;",
  "}",
  "",
  "render(<Index/>, document.getElementsByTagName(\"body\")[0]);"
}
M.preact.code["src/style.css"] = {
  "* {",
  "  margin: 0;",
  "  padding: 0;",
  "}",
  "",
  ":root {",
  "  font-family: sans-serif, system-ui, Arial;",
  "  line-height: 1.2;",
  "  font-weight: 500;",
  "",
  "  color: #ffffff;",
  "",
  "  font-synthesis: none;",
  "  text-rendering: optimizeLegibility;",
  "  -webkit-font-smoothing: antialiased;",
  "  -moz-osx-font-smoothing: grayscale;",
  "}",
  "",
  "html, body {",
  "  height: 100vh;",
  "  width: 100vw;",
  "  background-color: #333;",
  "}",
  "",
  "body, header, nav, .main {",
  "  display: flex;",
  "  justify-content: center;",
  "}",
  "",
  ".main {",
  "  align-items: center;",
  "}",
  "",
  "header {",
  "  position: absolute;",
  "  top: 0;",
  "}",
  "",
  "nav {",
  "  --color: rgb(96, 64, 192);",
  "  height: 50px;",
  "  background-color: white;",
  "  padding: 0 8px;",
  "  border-bottom-left-radius:  24px;",
  "  border-bottom-right-radius: 24px;",
  "",
  "  & > a {",
  "    margin: 0 8px;",
  "    display: flex;",
  "    align-items: center;",
  "    color: black;",
  "    text-decoration: none;",
  "    font-weight: bold;",
  "  }",
  "",
  "  & > .active {",
  "    position: relative;",
  "    color: var(--color);",
  "  }",
  "",
  "  & > .active::before {",
  "    --size: 6px;",
  "    content: '';",
  "    width: 0;",
  "    height: 0;",
  "    position: absolute;",
  "    top: 0;",
  "    left: calc(50% - var(--size));",
  "    border: var(--size) solid transparent;",
  "    border-top: var(--size) solid var(--color);",
  "  }",
  "}"
}

M.preact.code["src/pages/E404/index.tsx"] = {
  "export function E404() {",
  "  return <h1>404</h1>;",
  "}"
}
M.preact.code["src/pages/Home/index.tsx"] = {
  "import { Message } from \"@/components/Message.tsx\";",
  "",
  "export function Home() {",
  "  return <Message text=\"" .. MESSAGE .. "\"/>;",
  "}"
}
M.preact.code["src/components/Header.tsx"] = {
  "import { useLocation } from \"preact-iso\";",
  "",
  "export function Header(){",
  "  const { url } = useLocation();",
  "",
  "  return <header>",
  "    <nav>",
  "      <a href=\"/\" class={ url == \"/\" && \"active\"  }>Home</a>",
  "      <a href=\"/404\" class={ url == \"/404\" && \"active\" }>404</a>",
  "    </nav>",
  "  </header>;",
  "}"
}
M.preact.code["src/components/Message.tsx"] = {
  "export function Message({ text }: { text: string }) {",
  "  return <h1>{ text }</h1>",
  "}"
}
M.preact.code[".gitignore"] = gitignore

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
