augroup MkdGui
    " These autocmd calling s:MarkdownRefreshSyntax need to be kept in sync with
    " the autocmds calling s:MarkdownSetupFolding in after/ftplugin/markdown.vim.
    autocmd! * <buffer>
    autocmd BufWinEnter <buffer> lua require("gui-widgets").refresh_mkd(0)
    " autocmd BufUnload <buffer> call s:MarkdownClearSyntaxVariables()
    autocmd BufWritePost <buffer> lua require("gui-widgets").refresh_mkd(0)
    autocmd InsertEnter,InsertLeave lua require("gui-widgets").refresh_mkd(0)
    autocmd CursorHold,CursorHoldI lua require("gui-widgets").refresh_mkd(0)
augroup END

