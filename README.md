# gui-widgets.nvim -- supporting library for gui widgets

Attaching pictures to a buffer:
```vimL
function TestGuiWidget()
  let w1 = GuiWidgetPut("F:/test/1.png","image/png")
  let w2 = GuiWidgetPut("F:/test/2.png","image/png")
  call GuiWidgetPlace(w1, 0, 1, 0, 20, 5)
  call GuiWidgetPlace(w2, 0, 6, 0, 20, 5)
  call GuiWidgetUpdateView(0)
endfunction
```

Front-end GUI startup logic:
```vimL
if exists("g:gui_widgets")
  " attach ui channel to gui widget rpc notifications
  call GuiWidgetClientAttach(g:fvim_channel)
endif
```

RPC notifications:
```lua
vim.rpcnotify(clientChannel,"GuiWidgetPut", {
  id = 123;               -- the gui widget id
  mime = "image/png";     -- the mime data, client chooses how to present
  data = { ... };         -- binary data, serializes to str8 in msgpack
})

vim.rpcnotify(clientChannel, "GuiWidgetUpdateView", {
  buf = 5;                -- the updated buffer
  widgets = {
    { 123, 1, 5, 10, 20 } -- [widget_id, row, col, width, height] tuple
  }
})
```

When a plugin calls `GuiWidgetPut`, it will be sent right away to the client after it's loaded from the path.
The client may use a LRU cache to evict resources, and use `GuiWidgetRequest` later if the cache misses.

## Animation
First put all the frames so the client has them.
Then, refer to the frames by the gui widget ids to update the frame.

## TODO
- `GuiWidgetRequest` should be rpcnotify, not a function -- so it can be used in redraw.
- win_viewport does not have horizontal scroll information and sign column/number column sizes...
