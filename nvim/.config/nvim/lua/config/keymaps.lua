-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("x", "(", 'c(<C-r>")')
vim.keymap.set("x", "[", 'c[<C-r>"]')
vim.keymap.set("x", "{", 'c{<C-r>"}')
vim.keymap.set("n", "gy", '"+y')
vim.keymap.set("x", "gy", '"+y')
vim.keymap.set("n", "<leader>cp", ':let @+ = expand("%:p")<CR>')
vim.keymap.set("n", "<CR>", "o<Esc>")
vim.keymap.set("n", "<S-CR>", "O<Esc>")
