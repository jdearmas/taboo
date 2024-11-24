# Taboo.nvim

A Neovim Lua plugin for managing the tabline, inspired by [taboo.vim](https://github.com/gcmt/taboo.vim).

## Features

- Rename tabs with custom names.
- Customize tab titles and formats.
- Display indicators for modified buffers.

## Installation

### **Using [lazy](https://github.com/folke/lazy.nvim)**

```lua
{
  'jdearmas/taboo.nvim',
    config = function()
      require('taboo').setup({
          -- Your configuration options
          taboo_tabline = 1,
          taboo_tab_format = " %f%m ",
          taboo_renamed_tab_format = " [%l]%m ",
          taboo_modified_tab_flag = "*",
          taboo_close_tabs_label = "",
          taboo_close_tab_label = "x",
          taboo_unnamed_tab_label = "[no name]",
          })
  end,
},
```

### **Set Keybindings**

```lua
vim.api.nvim_set_keymap("n", "<leader>tn", ":tabnew<CR>", { noremap = true })
vim.api.nvim_set_keymap("n", "<leader>tr", ":TabooRename<Space>", { noremap = true })
```

## Acknowledgments

This plugin is inspired by [taboo.vim](https://github.com/gcmt/taboo.vim) by [Giacomo Comitti](https://github.com/gcmt). 
The original plugin provided a foundation for managing the tabline in Vim. 
This project extends that functionality for Neovim using Lua.
