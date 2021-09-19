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

function GuiWidgetPutFile(path, mime)
  return luaeval('require("gui-widgets").put_file(_A[1],_A[2])', [a:path,a:mime])
endfunction

function GuiWidgetPutData(data, mime)
  return luaeval('require("gui-widgets").put_data(_A[1],_A[2])', [a:data,a:mime])
endfunction

function GuiWidgetDelete(id)
  return luaeval('require("gui-widgets").del(_A)',a:id)
endfunction

function GuiWidgetPlace(id,bufnr,row,col,w,h,...)
  if a:0 > 0
    return luaeval('require("gui-widgets").place(_A[1],_A[2],_A[3],_A[4],_A[5],_A[6],_A[7])',[a:id,a:bufnr,a:row,a:col,a:w,a:h,a:1])
  else
    return luaeval('require("gui-widgets").place(_A[1],_A[2],_A[3],_A[4],_A[5],_A[6])',[a:id,a:bufnr,a:row,a:col,a:w,a:h])
  endif
endfunction

function GuiWidgetUpdateView(buf)
  call luaeval('require("gui-widgets").update_view(_A)',a:buf)
endfunction

let g:gui_widgets=1
