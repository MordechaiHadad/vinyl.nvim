local M = {}

local LSP_BIN = "vinyl-lsp"
local REPO_URL = "https://github.com/MordechaiHadad/vinyl-lang.git"
local BRANCH = "dev"

function M.register_treesitter()
  vim.treesitter.language.register("vinyl", "vinyl")

  local ok, ts_install = pcall(require, "nvim-treesitter.install")
  if ok and ts_install.compilers then
    -- Modern nvim-treesitter main branch registration
    if not ts_install.ensure_installed_parsers then
      -- If using the modern command registry, map via language info if available
    end
  end

  -- Fallback: Register directly into Neovim's parser query runtime path loader
  local parser_config = rawget(require("nvim-treesitter"), "parsers")
  if parser_config and type(parser_config.get_parser_configs) == "function" then
    local configs = parser_config.get_parser_configs()
    if configs and not configs.vinyl then
      configs.vinyl = {
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
    local root_dir = vim.fs.root(0, { ".git", "specs.md", "Cargo.toml" }) or buf_dir

    vim.lsp.start({
      name = "vinyl-lsp",
      cmd = { LSP_BIN },
      root_dir = root_dir,
    })
  end)
end

return M
