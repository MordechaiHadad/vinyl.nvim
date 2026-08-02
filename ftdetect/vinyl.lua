vim.filetype.add({
    extension = {
        vn = "vinyl",
    },
})

vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
vim.bo.indentkeys = "0{,0},0),0],0#,!^F,o,O,e"
