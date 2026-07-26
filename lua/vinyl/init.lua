local M = {}

local LSP_BIN = "vinyl-lsp"
local REPO_URL = "https://github.com/MordechaiHadad/vinyl-lang.git"
local BRANCH = "dev"

--- Registers the Vinyl parser mapping and nvim-treesitter build configuration
function M.register_treesitter()
    -- Explicitly register the "vinyl" filetype to the "vinyl" tree-sitter parser
    pcall(vim.treesitter.language.register, "vinyl", "vinyl")

    -- Register source path with nvim-treesitter (allows :TSInstall vinyl)
    local ok, parsers = pcall(require, "nvim-treesitter.parsers")
    if not ok then
        return
    end

    local parser_config = parsers.get_parser_configs()
    if not parser_config.vinyl then
        parser_config.vinyl = {
            install_info = {
                url = REPO_URL,
                files = { "src/parser.c" }, -- add "src/scanner.c" if your grammar uses an external scanner
                location = "grammar", -- points to vinyl-lang/grammar/ inside the monorepo
                branch = BRANCH,
            },
            filetype = "vinyl",
        }
    end
end

--- Ensures vinyl-lsp exists in PATH, or builds it asynchronously via cargo
---@param callback function(success: boolean)
local function ensure_lsp(callback)
    -- 1. Check if executable already exists in PATH
    if vim.fn.executable(LSP_BIN) == 1 then
        callback(true)
        return
    end

    -- 2. Check if Cargo is installed
    if vim.fn.executable("cargo") == 0 then
        vim.notify(
            "[vinyl.nvim] 'vinyl-lsp' was not found in PATH and 'cargo' is not installed.\n" ..
            "Please install Rust/Cargo (https://rustup.rs/) to enable automatic LSP compilation.",
            vim.log.levels.ERROR
        )
        callback(false)
        return
    end

    -- 3. Run cargo install asynchronously from git
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

--- Main setup function called on filetype activation
function M.setup()
    -- Register Tree-sitter configurations
    M.register_treesitter()

    -- Bootstrap LSP and attach client
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
