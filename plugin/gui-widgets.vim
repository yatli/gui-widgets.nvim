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

function GuiWidgetPlace(id,bufnr,row,col)
  return luaeval('require("gui-widgets").place(_A[1],_A[2],_A[3],_A[4])',a:id,a:bufnr,a:row,a:col)
endfunction

let g:gui_widgets=1
