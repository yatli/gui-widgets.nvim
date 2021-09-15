if exists('g:gui_widgets')
  finish
endif
lua require("gui-widgets").start()

function GuiWidgetClientAttach(chan)
  return luaeval('require("gui-widgets").attach(_A)',a:chan)
endfunction

" TODO should be an rpcnotify handler instead
function GuiWidgetRequest(id)
  call luaeval('require("gui-widgets").request(_A)',a:id)
endfunction

function GuiWidgetPut(path, mime)
  return luaeval('require("gui-widgets").put(_A[1],_A[2])', [a:path,a:mime])
endfunction

function GuiWidgetDelete(id)
  return luaeval('require("gui-widgets").del(_A)',a:id)
endfunction

function GuiWidgetPlace(id,bufnr,row,col,w,h)
  return luaeval('require("gui-widgets").place(_A[1],_A[2],_A[3],_A[4],_A[5],_A[6])',[a:id,a:bufnr,a:row,a:col,a:w,a:h])
endfunction

function GuiWidgetUpdateView(buf)
  call luaeval('require("gui-widgets").update_view(_A)',a:buf)
endfunction

augroup GuiWidget
  autocmd TextChanged * call luaeval('require("gui-widgets").update_view(_A)', expand("<abuf>"))
  autocmd TextChangedI * call luaeval('require("gui-widgets").update_view(_A)', expand("<abuf>"))
  autocmd TextChangedP * call luaeval('require("gui-widgets").update_view(_A)', expand("<abuf>"))
augroup END

let g:gui_widgets=1
