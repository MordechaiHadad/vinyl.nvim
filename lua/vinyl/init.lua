local M = {}

local LSP_BIN = "vinyl-lsp"
local REPO_URL = "https://github.com/MordechaiHadad/vinyl-lang.git"
local BRANCH = "dev"

function M.build_parser()
    local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
    local grammar_dir = plugin_dir .. "/grammar"
    local parser_out = plugin_dir .. "/parser"

    vim.fn.mkdir(parser_out, "p")

    local is_windows = vim.uv.os_uname().sysname:match("Windows") ~= nil
    local ext = is_windows and ".dll" or ".so"
    local output_file = parser_out .. "/vinyl" .. ext
    local source_file = grammar_dir .. "/src/parser.c"

    if vim.fn.filereadable(source_file) == 0 then
        vim.notify("[vinyl.nvim] Parser source not found at " .. source_file, vim.log.levels.ERROR)
        return
    end

    local compiler = vim.fn.executable("gcc") == 1 and "gcc" or (vim.fn.executable("clang") == 1 and "clang" or "zig")
    local cmd

    if compiler == "gcc" or compiler == "clang" then
        if is_windows then
            cmd = { compiler, "-shared", "-O2", "-I", grammar_dir .. "/src", "-o", output_file, source_file }
        else
            cmd = { compiler, "-shared", "-fPIC", "-O2", "-I", grammar_dir .. "/src", "-o", output_file, source_file }
        end
    elseif compiler == "zig" then
        cmd = { "zig", "cc", "-shared", "-O2", "-I", grammar_dir .. "/src", "-o", output_file, source_file }
    else
        vim.notify("[vinyl.nvim] No C compiler found (gcc, clang, or zig required to build parser).",
            vim.log.levels.ERROR)
        return
    end

    vim.system(cmd, { text = true }, function(obj)
        vim.schedule(function()
            if obj.code == 0 then
                vim.notify("[vinyl.nvim] Parser built successfully!", vim.log.levels.INFO)
            else
                vim.notify("[vinyl.nvim] Parser build failed:\n" .. (obj.stderr or "Unknown error"), vim.log.levels
                .ERROR)
            end
        end)
    end)
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
        local root_dir = vim.fs.root(0, { ".git", "specs.md", "Cargo.toml" }) or buf_dir

        vim.lsp.start({
            name = "vinyl-lsp",
            cmd = { LSP_BIN },
            root_dir = root_dir,
        })
    end)
end

return M
