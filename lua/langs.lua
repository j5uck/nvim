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
  vim.fn.mkdir(dir, "p")
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

-- vim.cmd[[silent! %s/\\/\\\\/g]]
-- vim.cmd[[silent! %s/"/\\"/g]]
-- vim.cmd[[%norm 0i  "]]
-- vim.cmd[[%norm $a",]]

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
  "",
  "    \"paths\": {",
  "      \"@/*\": [ \"./src/*\" ]",
  "    },",
  "    \"lib\": [",
  "      \"dom\",",
  "      \"WebWorker\",",
  "      \"ESNext\"",
  "    ],",
  "",
  "    \"alwaysStrict\": true,",
  "    \"noImplicitAny\": true,",
  "    \"noImplicitThis\": true,",
  "    \"strict\": true,",
  "    \"strictBindCallApply\": true,",
  "    \"strictFunctionTypes\": true,",
  "    \"strictNullChecks\": true,",
  "    \"strictPropertyInitialization\": true,",
  "",
  "    \"allowImportingTsExtensions\": true,",
  "    \"noFallthroughCasesInSwitch\": true,",
  "    \"noImplicitReturns\": true,",
  "    // \"noUncheckedIndexedAccess\": true,",
  "    \"noUnusedLocals\": true,",
  "    \"noUnusedParameters\": true,",
  "",
  "    \"noEmit\": true,",
  "    \"removeComments\": true,",
  "    \"skipLibCheck\": true,",
  "",
  "    \"types\": [ \"bun-types\" ]",
  "  }",
  "}"
}
local bunfig_toml = {
  "telemetry = false",
  "",
  "[console]",
  "depth = 3",
  "",
  "[install]",
  "auto = \"auto\"",
  "# 1 week",
  "minimumReleaseAge = " .. tostring(60 * 60 * 24 * 7),
  "",
  "[install.lockfile]",
  "save = false",
  "",
  "[run]",
  "bun = true",
  "noOrphans = true",
  "shell = \"bun\""
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
    :cmd({ fs.exepath("cc"), "-o", "main", "src/main.c" })
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
  "    \"tsc\": \"bun build.ts -- tsc\",",
  "    \"dev\": \"bun build.ts -- dev\",",
  "    \"web\": \"bun build.ts -- web\",",
  "    \"bin\": \"bun build.ts -- bin\"",
  "  },",
  "  \"devDependencies\": {",
  "    \"@types/bun\": \"*\",",
  "    \"typescript\": \"*\"",
  "  }",
  "}"
}
M.bun.code["tsconfig.json"] = tsconfig_json
M.bun.code["bunfig.toml"] = bunfig_toml
M.bun.code[".env"] = {
  "PORT=8080"
}
M.bun.code["build.ts"] = {
  "import fs from \"fs\";",
  "import path from \"path\";",
  "import { spawn } from \"child_process\";",
  "",
  "function sh(cmd: string[], env?: Record<string, string>): Promise<void>{",
  "  return new Promise((resolve, reject) => {",
  "    spawn(cmd[0], cmd.slice(1), { stdio : \"inherit\", env: { ...process.env, ...(env || {}) } })",
  "      .on(\"exit\", (code: number) => code === 0 ? resolve() : reject(code))",
  "  });",
  "}",
  "",
  "const ENTRYPOINT = \"src/server.ts\";",
  "const OUTDIR = \"build/\";",
  "",
  "const plugins: Bun.BunPlugin[] = [{",
  "  name: \"HTML handler\",",
  "  setup(build) {",
  "    build.onLoad({ filter: /\\.html$/ }, async (args) => {",
  "      const contents = (await Bun.file(args.path).text()).replace(/[\\s\\t]*[\\r\\n]+[\\s\\t]*/g, \"\");",
  "      return { loader: \"e.html\" === path.basename(args.path) ? \"text\" : \"html\", contents };",
  "    });",
  "  }",
  "}];",
  "",
  "const ACTIONS: Record<string, () => Promise<void>> = {};",
  "",
  "ACTIONS.HELP = async () => {",
  "  process.stderr.write(\"Commands: \" + Object.keys(ACTIONS).join(\", \").toLowerCase() + \"\\n\");",
  "};",
  "",
  "ACTIONS.CLEAN = async () => {",
  "  try{",
  "    fs.rmSync(OUTDIR, { recursive: true });",
  "  }catch(e){ }",
  "};",
  "",
  "ACTIONS.TSC = async () => {",
  "  await sh([ \"bun\", \"x\", \"--bun\", \"tsc\", \"--noEmit\" ]);",
  "};",
  "",
  "ACTIONS.DEV = async () => {",
  "  fs.mkdirSync(OUTDIR, { recursive: true });",
  "  await sh([ \"bun\", \"--bun\", ENTRYPOINT, \"--\", ...process.argv.slice(3) ], { NODE_ENV: \"development\" });",
  "};",
  "",
  "ACTIONS.WEB = async () => {",
  "  await ACTIONS.CLEAN();",
  "  await ACTIONS.TSC();",
  "  await Bun.build({",
  "    entrypoints: [ ENTRYPOINT ],",
  "    outdir: OUTDIR,",
  "    minify: true,",
  "    target: \"bun\",",
  "    plugins,",
  "    env: \"inline\",",
  "    define: {",
  "      \"process.env.NODE_ENV\": JSON.stringify(\"production\"),",
  "      \"process.env.NODE_ENV_VERBOSE\": JSON.stringify(\"production-web\")",
  "    }",
  "  });",
  "  await sh([ \"bun\", \"--bun\", OUTDIR + \"server.js\", \"--\", ...process.argv.slice(3) ]);",
  "};",
  "",
  "ACTIONS.BIN = async () => {",
  "  await ACTIONS.CLEAN();",
  "  await ACTIONS.TSC();",
  "  await Bun.build({",
  "    entrypoints: [ ENTRYPOINT ],",
  "    compile: { outfile: OUTDIR + \"server\" },",
  "    minify: true,",
  "    target: \"bun\",",
  "    plugins,",
  "    env: \"inline\",",
  "    define: {",
  "      \"process.env.NODE_ENV\": JSON.stringify(\"production\"),",
  "      \"process.env.NODE_ENV_VERBOSE\": JSON.stringify(\"production-binary\")",
  "    }",
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
  "",
  "import assert from \"@/assert.ts\";",
  "import routes from \"@/routes.ts\";",
  "import * as T from \"@/terminal.ts\";",
  "",
  "if(process.env.NODE_ENV === \"production\")",
  "  process.chdir(",
  "    process.env.NODE_ENV_VERBOSE === \"production-web\" ?",
  "      path.dirname(import.meta.path) :",
  "    process.env.NODE_ENV_VERBOSE === \"production-binary\" ?",
  "      path.dirname(process.execPath) :",
  "    assert(false, \"Unsupported target \\\"\" + process.env.NODE_ENV_VERBOSE + \"\\\"\") as any",
  "  );",
  "",
  "let port = parseInt(process.env.PORT as string);",
  "if(process.env.NODE_ENV === \"development\")",
  "  while(true){",
  "    try {",
  "      await new Promise<void>((resolve, reject) => {",
  "        var server = net.createServer();",
  "        server.once(\"listening\", () => { server.close(); resolve(); });",
  "        server.once(\"error\", e => { server.close(); reject(e); });",
  "        server.listen(port);",
  "      });",
  "      break;",
  "    } catch (e: any) {",
  "      if(e.code !== \"EADDRINUSE\")",
  "        throw e;",
  "      ++port;",
  "    }",
  "  }",
  "",
  "// https://bun.com/docs/runtime/http/server",
  "const server: Bun.Server<undefined> = Bun.serve({ port, routes });",
  "",
  "const _TAG = process.env.NODE_ENV === \"development\" ?",
  "    (T.BG_BLUE + T.FG_WHITE + \" DEV \" + T.RESET) :",
  "    (T.BG_GREY + T.FG_WHITE + \" PRODUCTION \" + T.RESET);",
  "",
  "process.stdout.write(",
  "  _TAG + \" \" + T.FG_BLUE + \"Bun v\" + Bun.version + T.RESET + \"\\n\" +",
  "  \"\\n\" +",
  "  T.FG_BLUE + \"➜ \" + T.RESET + T.FG_CYAN_DARK + \"http://localhost:\" + server.port + \"/\" + T.RESET + \"\\n\" +",
  "  \"\\n\"",
  ");"
}
M.bun.code["src/routes.ts"] = {
  "import index from \"@/view/index.html\";",
  "",
  "// https://bun.com/docs/runtime/http/routing",
  "export default {",
  "  \"/\": index,",
  "  \"/*\": Response.json({ message: \"Not found\" }, { status: 404 })",
  "} satisfies Bun.Serve.Routes<undefined, string>;",
}
M.bun.code["src/assert.ts"] = {
  "class AssertionError extends Error {",
  "  constructor(message?: string) {",
  "    super(message);",
  "    this.name = \"AssertionError\";",
  "  }",
  "}",
  "",
  "export default (value: any, message?: string): void => {",
  "  if(!value)",
  "    throw new AssertionError(message as any);",
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
M.bun.code["src/view/global.d.ts"] = {
  "declare module \"*.css\";"
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
  "import Message from \"@/view/message/e.ts\";",
  "",
  "document.body.append(Message.create({ text: \"" .. MESSAGE .. "\" }));"
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
  "}"
}
M.bun.code["src/view/message/e.html"] = {
  "<div></div>"
}
M.bun.code["src/view/message/e.ts"] = {
  "import \"@/view/message/e.css\";",
  "",
  "import message_html from \"@/view/message/e.html\" with { type: \"text\" };",
  "",
  "const message: HTMLDivElement = (() => {",
  "  const _ = document.createElement(\"div\");",
  "  _.innerHTML = message_html as unknown as string;",
  "  return _.firstElementChild as HTMLDivElement;",
  "})();",
  "",
  "export default {",
  "  create: (e: { text: string }) => {",
  "    const r = message.cloneNode(true) as HTMLDivElement;",
  "    r.classList.add(\"message_element\");",
  "    r.innerText = e.text;",
  "    return r;",
  "  }",
  "};"
}
M.bun.code["src/view/message/e.css"] = {
  ".message_element {",
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
    :cmd(list.merge({ fs.exepath("javac"), "-d", "build" }, javas))
    :cd("build")
    :cmd(list.merge({ fs.exepath("jar"), "-cfe", "Main.jar", "src/Main" }, fs.find("\\.class$", "build"):await():unwrap()))
    :cmd{ fs.exepath("java"), "-jar", "Main.jar" }
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
    :cmd(list.merge({ fs.exepath("kotlinc"), "-Wextra", "-d", "build/Main.jar" }, kts))
    :cmd{ fs.exepath("java"), "-jar", "build/Main.jar" }
  promise:resolve()
end)

M.lua.init = { "script.lua" }
M.lua.code = {}
M.lua.code["script.lua"] = {
  "vim.notify(\"" .. MESSAGE .. "\", vim.log.levels.WARN)"
}

return M
