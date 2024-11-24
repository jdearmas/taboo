-- File: lua/taboo/init.lua
-- Description: A Lua plugin for managing the Neovim tabline
-- Maintainer: John De Armas (https://github.com/jdearmas)
-- URL: https://github.com/jdearmas/taboo
-- License: MIT

local M = {}

-- Default configuration
M.config = {
  taboo_tabline = 1,
  taboo_tab_format = " %f%m ",
  taboo_renamed_tab_format = " [%l]%m ",
  taboo_modified_tab_flag = "*",
  taboo_close_tabs_label = "",
  taboo_close_tab_label = "x",
  taboo_unnamed_tab_label = "[no name]",
}

-- Per-tab variables
M.tabs = {}

-- Setup function
function M.setup(opts)
  M.config = vim.tbl_extend('force', M.config, opts or {})
  M.init()
end

-- Initialization
function M.init()
  if M.config.taboo_tabline ~= 0 then
    vim.o.tabline = '%!v:lua.require("taboo").tabline()'
  end

  -- Create user commands
  vim.api.nvim_create_user_command('TabooRename', function(opts)
    M.rename_tab(opts.args)
  end, { nargs = 1 })

  vim.api.nvim_create_user_command('TabooOpen', function(opts)
    vim.cmd('tabnew')
    M.rename_tab(opts.args)
  end, { nargs = 1 })

  vim.api.nvim_create_user_command('TabooReset', function()
    M.reset_tab_name()
  end, { nargs = 0 })

  -- Set up autocommands
  vim.api.nvim_create_autocmd({ 'TabEnter', 'TabLeave' }, {
    callback = function()
      M.refresh_tabline()
    end,
  })

  vim.api.nvim_create_autocmd('TabClosed', {
    callback = function(event)
      local tabnr = tonumber(event.match)
      M.tabs[tabnr] = nil
    end,
  })
end

-- Function to refresh the tabline
function M.refresh_tabline()
  vim.cmd('redrawtabline')
end

-- Tabline function
function M.tabline()
  local tabline = ''
  local tabs = vim.api.nvim_list_tabpages()
  local current_tab = vim.api.nvim_get_current_tabpage()
  for _, tab in ipairs(tabs) do
    local tabnr = vim.api.nvim_tabpage_get_number(tab)
    local hl = (tab == current_tab) and '%#TabLineSel#' or '%#TabLine#'
    tabline = tabline .. hl

    local title = M.tabname(tab)
    local fmt = (title == '') and M.config.taboo_tab_format or M.config.taboo_renamed_tab_format

    tabline = tabline .. '%' .. tabnr .. 'T'
    tabline = tabline .. M.expand(tab, fmt)
  end

  tabline = tabline .. '%#TabLineFill#%T'
  tabline = tabline .. '%=%#TabLine#%999X' .. M.config.taboo_close_tabs_label

  return tabline
end

-- Expand function
function M.expand(tab, fmt)
  local out = fmt

  local substitutions = {
    ["%%f"] = function()
      return M.bufname(tab)
    end,
    ["%%F"] = function()
      return M.bufname_current_win(tab)
    end,
    ["%%a"] = function()
      return M.bufpath(tab, false)
    end,
    ["%%A"] = function()
      return M.bufpath_current_win(tab, false)
    end,
    ["%%r"] = function()
      return M.bufpath(tab, true)
    end,
    ["%%R"] = function()
      return M.bufpath_current_win(tab, true)
    end,
    ["%%n"] = function()
      return M.tabnum(tab, false)
    end,
    ["%%N"] = function()
      return M.tabnum(tab, true)
    end,
    ["%%i"] = function()
      return M.tabnum_unicode(tab, false)
    end,
    ["%%I"] = function()
      return M.tabnum_unicode(tab, true)
    end,
    ["%%w"] = function()
      return M.wincount(tab, false)
    end,
    ["%%W"] = function()
      return M.wincount(tab, true)
    end,
    ["%%u"] = function()
      return M.wincount_unicode(tab, false)
    end,
    ["%%U"] = function()
      return M.wincount_unicode(tab, true)
    end,
    ["%%m"] = function()
      return M.modflag(tab)
    end,
    ["%%l"] = function()
      return M.tabname(tab)
    end,
    ["%%p"] = function()
      return M.tabpwd(tab, 0)
    end,
    ["%%P"] = function()
      return M.tabpwd(tab, 1)
    end,
    ["%%S"] = function()
      return M.tabpwd(tab, 2)
    end,
    ["%%x"] = function()
      return M.tabclose(tab)
    end,
  }

  for placeholder, func in pairs(substitutions) do
    out = out:gsub(placeholder, func())
  end

  return out
end

-- Function to get the tab name
function M.tabname(tab)
  local tabnr = vim.api.nvim_tabpage_get_number(tab)
  if M.tabs[tabnr] and M.tabs[tabnr].taboo_tab_name then
    return M.tabs[tabnr].taboo_tab_name
  else
    return ''
  end
end

-- Function to get the buffer name
function M.bufname(tab)
  local wins = vim.api.nvim_tabpage_list_wins(tab)
  local buffers = {}
  for _, win in ipairs(wins) do
    local buf = vim.api.nvim_win_get_buf(win)
    table.insert(buffers, buf)
  end
  local buf = M.first_normal_buffer(buffers) or buffers[1]
  local bname = vim.api.nvim_buf_get_name(buf)
  if bname ~= '' then
    return vim.fn.fnamemodify(bname, ':t')
  end
  return M.config.taboo_unnamed_tab_label
end

function M.bufname_current_win(tab)
  local win = vim.api.nvim_tabpage_get_win(tab)
  local buf = vim.api.nvim_win_get_buf(win)
  local bname = vim.api.nvim_buf_get_name(buf)
  if bname ~= '' then
    return vim.fn.fnamemodify(bname, ':t')
  end
  return M.config.taboo_unnamed_tab_label
end

function M.tabnum(tab, ubiquitous)
  local tabnr = vim.api.nvim_tabpage_get_number(tab)
  if ubiquitous or tab == vim.api.nvim_get_current_tabpage() then
    return tostring(tabnr)
  else
    return ''
  end
end

function M.number_to_unicode(number)
  local small_numbers = { '⁰', '¹', '²', '³', '⁴', '⁵', '⁶', '⁷', '⁸', '⁹' }
  local number_str = tostring(number)
  local unicode_number = ''
  for i = 1, #number_str do
    local digit = tonumber(number_str:sub(i, i))
    unicode_number = unicode_number .. small_numbers[digit + 1]
  end
  return unicode_number
end

function M.tabnum_unicode(tab, ubiquitous)
  local tabnr = vim.api.nvim_tabpage_get_number(tab)
  local number_to_show = M.number_to_unicode(tabnr)
  if ubiquitous or tab == vim.api.nvim_get_current_tabpage() then
    return number_to_show
  else
    return ''
  end
end

function M.wincount(tab, ubiquitous)
  local wins = vim.api.nvim_tabpage_list_wins(tab)
  local wincount = #wins
  if ubiquitous or tab == vim.api.nvim_get_current_tabpage() then
    return tostring(wincount)
  else
    return ''
  end
end

function M.wincount_unicode(tab, ubiquitous)
  local wins = vim.api.nvim_tabpage_list_wins(tab)
  local wincount = #wins
  local number_to_show = M.number_to_unicode(wincount)
  if ubiquitous or tab == vim.api.nvim_get_current_tabpage() then
    return number_to_show
  else
    return ''
  end
end

function M.modflag(tab)
  local flag = M.config.taboo_modified_tab_flag
  local wins = vim.api.nvim_tabpage_list_wins(tab)
  for _, win in ipairs(wins) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.api.nvim_buf_get_option(buf, 'modified') then
      if M.config.taboo_tabline ~= 0 then
        if tab == vim.api.nvim_get_current_tabpage() then
          return '%#TabModifiedSelected#' .. flag .. '%#TabLineSel#'
        else
          return '%#TabModified#' .. flag .. '%#TabLine#'
        end
      else
        return flag
      end
    end
  end
  return ''
end

function M.tabpwd(tab, last_component)
  local tabnr = vim.api.nvim_tabpage_get_number(tab)
  if tab == vim.api.nvim_get_current_tabpage() then
    local cwd = vim.fn.getcwd()
    M.tabs[tabnr] = M.tabs[tabnr] or {}
    M.tabs[tabnr].taboo_tab_wd = cwd
  end

  local tabcwd = M.tabs[tabnr] and M.tabs[tabnr].taboo_tab_wd or ''

  if last_component == 1 then
    local parts = vim.split(tabcwd, '/')
    return parts[#parts] or ''
  elseif last_component == 2 then
    return vim.fn.pathshorten(vim.fn.fnamemodify(tabcwd, ':~'))
  else
    return tabcwd
  end
end

function M.tabclose(tab)
  local tabnr = vim.api.nvim_tabpage_get_number(tab)
  return '%' .. tabnr .. 'X' .. M.config.taboo_close_tab_label .. '%X'
end

function M.bufpath(tab, relative)
  local wins = vim.api.nvim_tabpage_list_wins(tab)
  local buffers = {}
  for _, win in ipairs(wins) do
    local buf = vim.api.nvim_win_get_buf(win)
    table.insert(buffers, buf)
  end
  local buf = M.first_normal_buffer(buffers) or buffers[1]
  local bname = vim.api.nvim_buf_get_name(buf)
  if bname ~= '' then
    if relative then
      return bname
    else
      return vim.fn.fnamemodify(bname, ':p')
    end
  end
  return M.config.taboo_unnamed_tab_label
end

function M.bufpath_current_win(tab, relative)
  local win = vim.api.nvim_tabpage_get_win(tab)
  local buf = vim.api.nvim_win_get_buf(win)
  local bname = vim.api.nvim_buf_get_name(buf)
  if bname ~= '' then
    if relative then
      return bname
    else
      return vim.fn.fnamemodify(bname, ':p')
    end
  end
  return M.config.taboo_unnamed_tab_label
end

function M.first_normal_buffer(buffers)
  for _, buf in ipairs(buffers) do
    if vim.api.nvim_buf_get_option(buf, 'buflisted') and vim.api.nvim_buf_get_option(buf, 'buftype') ~= 'nofile' then
      return buf
    end
  end
  return nil
end

-- Commands
function M.rename_tab(label)
  local tabnr = vim.api.nvim_tabpage_get_number(0)
  M.tabs[tabnr] = M.tabs[tabnr] or {}
  M.tabs[tabnr].taboo_tab_name = label
  M.refresh_tabline()
end

function M.reset_tab_name()
  local tabnr = vim.api.nvim_tabpage_get_number(0)
  if M.tabs[tabnr] then
    M.tabs[tabnr].taboo_tab_name = nil
  end
  M.refresh_tabline()
end

return M

