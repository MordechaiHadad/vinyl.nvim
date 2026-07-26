local M = {}

local LSP_BIN = "vinyl-lsp"
local REPO_URL = "https://github.com/MordechaiHadad/vinyl-lang.git"
local BRANCH = "dev"

--- Safe registration for nvim-treesitter across breaking API changes
function M.register_treesitter()
    -- Core Neovim filetype-to-parser mapping
    pcall(vim.treesitter.language.register, "vinyl", "vinyl")

    local ok, parsers = pcall(require, "nvim-treesitter.parsers")
    if not ok then
        return
    end

    -- Handle API variations (legacy vs newer nvim-treesitter releases)
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
                files = { "src/parser.c" }, -- Add "src/scanner.c" if your grammar uses a custom scanner
                location = "grammar", -- Points to grammar/ inside the monorepo
                branch = BRANCH,
            },
            filetype = "vinyl",
        }
    end
end

--- Ensures vinyl-lsp exists in PATH or builds it asynchronously via cargo
---@param callback function(success: boolean)
local function ensure_lsp(callback)
    -- 1. Executable already available in PATH
    if vim.fn.executable(LSP_BIN) == 1 then
        callback(true)
        return
    end

    -- 2. Cargo installed?
    if vim.fn.executable("cargo") == 0 then
        vim.notify(
            "[vinyl.nvim] 'vinyl-lsp' was not found in PATH and 'cargo' is not installed.\n" ..
            "Please install Rust/Cargo (https://rustup.rs/) to enable automatic LSP compilation.",
            vim.log.levels.ERROR
        )
        callback(false)
        return
    end

    -- 3. Asynchronously build via cargo
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

--- Main setup function called on filetype trigger
function M.setup()
    M.register_treesitter()

    ensure_lsp(function(success)
        if not success then
            return
        end

        local root_dir = vim.fs.root(0, { ".git", "specs.md" }) or vim.fs.dirname(vim.api.nvim_buf_get_name(0))

        vim.lsp.start({
            name = "vinyl-lsp",
            cmd = { LSP_BIN },
            root_dir = root_dir,
        })
    end)
end

return M
