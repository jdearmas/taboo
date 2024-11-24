-- plugin/taboo.lua

if vim.g.loaded_taboo then
  return
end
vim.g.loaded_taboo = true

require('taboo').setup()
