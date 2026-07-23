return {
  {
    'folke/tokyonight.nvim',
    lazy = false,
    priority = 1000,
    config = function()
      require('tokyonight').setup({
        style = 'night',
        transparent = vim.uv.os_uname().sysname == 'Darwin'
          or string.find(vim.uv.os_uname().sysname, 'Windows') ~= nil
          or string.find(vim.uv.os_uname().release, 'WSL') ~= nil,
        styles = {
          comments = { italic = false },
          keywords = { italic = false },
        },
      })

      vim.cmd('colorscheme tokyonight-night')
    end,
  },
}
