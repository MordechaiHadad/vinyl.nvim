local M = {}

local LSP_BIN = "vinyl-lsp"
local REPO_URL = "https://github.com/MordechaiHadad/vinyl-lang.git"
local BRANCH = "dev"

function M.build_parser()
  local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
  local parser_out = plugin_dir .. "/parser"
  local src_dir = plugin_dir .. "/.parser-src"

  vim.fn.mkdir(parser_out, "p")

  local function compile_parser()
    local grammar_dir = src_dir .. "/grammar"
    if vim.fn.isdirectory(grammar_dir) == 0 then
      vim.notify("[vinyl.nvim] Grammar directory not found at " .. grammar_dir, vim.log.levels.ERROR)
      return
    end

    if vim.fn.executable("tree-sitter") == 0 then
      vim.notify("[vinyl.nvim] 'tree-sitter' CLI is required to build the parser.", vim.log.levels.ERROR)
      return
    end

    local is_windows = vim.uv.os_uname().sysname:match("Windows") ~= nil
    local ext = is_windows and ".dll" or ".so"
    local output_file = parser_out .. "/vinyl" .. ext

    local cmd = { "tree-sitter", "build", "--output", output_file, grammar_dir }

    vim.system(cmd, { text = true }, function(obj)
      vim.schedule(function()
        if obj.code == 0 then
          vim.notify("[vinyl.nvim] Parser built successfully via tree-sitter CLI!", vim.log.levels.INFO)
        else
          vim.notify("[vinyl.nvim] Parser build failed:\n" .. (obj.stderr or "Unknown error"), vim.log.levels.ERROR)
        end
      end)
    end)
  end

  if vim.fn.isdirectory(src_dir .. "/.git") == 1 then
    vim.system({ "git", "-C", src_dir, "pull", "origin", BRANCH }, { text = true }, function()
      vim.schedule(compile_parser)
    end)
  else
    vim.system({ "git", "clone", "--depth", "1", "--branch", BRANCH, REPO_URL, src_dir }, { text = true }, function()
      vim.schedule(compile_parser)
    end)
  end
end

function M.register_treesitter()
  vim.treesitter.language.register("vinyl", "vinyl")
end

local function ensure_lsp(callback)
  if vim.fn.executable(LSP_BIN) == 1 then
    callback(true)
    return
  end

  if vim.fn.executable("cargo") == 0 then
    vim.notify(
      "[vinyl.nvim] 'vinyl-lsp' not found and 'cargo' is missing.",
      vim.log.levels.ERROR
    )
    callback(false)
    return
  end

  local cmd = { "cargo", "install", "--git", REPO_URL, LSP_BIN, "--branch", BRANCH }

  if vim.system then
    vim.system(cmd, { text = true }, function(obj)
      vim.schedule(function()
        callback(obj.code == 0)
      end)
    end)
  else
    vim.fn.jobstart(cmd, {
      on_exit = function(_, code)
        vim.schedule(function()
          callback(code == 0)
        end)
      end,
    })
  end
end

function M.setup()
  M.register_treesitter()

  ensure_lsp(function(success)
    if not success then
      return
    end

    local buf_path = vim.api.nvim_buf_get_name(0)
    local buf_dir = buf_path ~= "" and vim.fs.dirname(buf_path) or vim.fn.getcwd()
    local root_dir = vim.fs.root(0, { ".git" }) or buf_dir

    vim.lsp.start({
      name = "vinyl-lsp",
      cmd = { LSP_BIN },
      root_dir = root_dir,
    })
  end)
end

return M
