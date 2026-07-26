local M = {}

local LSP_BIN = "vinyl-lsp"
local REPO_URL = "https://github.com/MordechaiHadad/vinyl-lang.git"
local BRANCH = "dev"

function M.register_treesitter()
  pcall(vim.treesitter.language.register, "vinyl", "vinyl")

  local ok, parsers = pcall(require, "nvim-treesitter.parsers")
  if not ok then
    return
  end

  local parser_config = nil
  if type(parsers.get_parser_configs) == "function" then
    parser_config = parsers.get_parser_configs()
  elseif type(parsers.list) == "table" then
    parser_config = parsers.list
  end

  if parser_config and not parser_config.vinyl then
    parser_config.vinyl = {
      install_info = {
        url = REPO_URL,
        files = { "src/parser.c" },
        location = "grammar",
        branch = BRANCH,
        requires_generate_from_grammar = false,
      },
      filetype = "vinyl",
      used_by = { "vinyl" },
    }
  end
end

local function ensure_lsp(callback)
  if vim.fn.executable(LSP_BIN) == 1 then
    callback(true)
    return
  end

  if vim.fn.executable("cargo") == 0 then
    vim.notify(
      "[vinyl.nvim] 'vinyl-lsp' was not found in PATH and 'cargo' is not installed.\n" ..
      "Please install Rust/Cargo (https://rustup.rs/) to enable automatic LSP compilation.",
      vim.log.levels.ERROR
    )
    callback(false)
    return
  end

  vim.notify(
    "[vinyl.nvim] 'vinyl-lsp' not found. Installing from git (" .. BRANCH .. " branch)...",
    vim.log.levels.INFO
  )

  local cmd = {
    "cargo", "install",
    "--git", REPO_URL,
    LSP_BIN,
    "--branch", BRANCH,
  }

  if vim.system then
    vim.system(cmd, { text = true }, function(obj)
      vim.schedule(function()
        if obj.code == 0 then
          vim.notify("[vinyl.nvim] 'vinyl-lsp' installed successfully!", vim.log.levels.INFO)
          callback(true)
        else
          vim.notify(
            "[vinyl.nvim] Cargo build failed:\n" .. (obj.stderr or "Unknown error"),
            vim.log.levels.ERROR
          )
          callback(false)
        end
      end)
    end)
  else
    vim.fn.jobstart(cmd, {
      on_exit = function(_, code)
        vim.schedule(function()
          if code == 0 then
            vim.notify("[vinyl.nvim] 'vinyl-lsp' installed successfully!", vim.log.levels.INFO)
            callback(true)
          else
            vim.notify("[vinyl.nvim] Cargo build failed.", vim.log.levels.ERROR)
            callback(false)
          end
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
