# gui-widgets.nvim -- supporting library for gui widgets

Attaching pictures to a buffer:
```vimL
function TestGuiWidget()
  let w1 = GuiWidgetPutFile("F:/test/1.png","image/png")
  let w2 = GuiWidgetPutFile("F:/test/2.png","image/png")
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
  id = 123;                -- the gui widget id
  mime = "image/png";      -- the mime data, client chooses how to present
  data = { ... };          -- binary data, serializes to str8 in msgpack
})

vim.rpcnotify(clientChannel, "GuiWidgetUpdateView", {
  buf = 5;                 -- the updated buffer
  widgets = {
    { 123, 1, 5, 10, 20 }, -- [widget_id, row, col, width, height] tuple
    { 234, 2, 0, 5, 1,     -- can have an opt dictionary
      { ['key'] = value; ... } 
    }
  }
})
```

When a plugin calls `GuiWidgetPut`, it will be sent right away to the client after it's loaded from the path.
The client may use a LRU cache to evict resources, and use `GuiWidgetRequest` later if the cache misses.

## Placement options
```lua
  gui.place(w1, 0, 0, 0, 8, 2, {
    ['clicked-widget']=w2;                            -- displays w2 when clicked
    ['clicked-exec']='silent call VsimToggleColor()'; -- callback on clicked
    ['released-widget']=w1;                           -- displays w1 when released
    ['halign']='center';                              -- left/center/right/stretch
    ['valign']='center';                              -- top/center/bottom/stretch
    ['stretch']='uniform';                            -- none/uniform/uniformfill
  })

  gui.place(w3, 0, 2, 0, 20, 2, {
    ['text-font']='Arial';
    ['text-scale']=2;                                 -- relative to guifont size
    ['text-hlid']='Normal';                           -- semantic highlight group name
    ['hide']='cursor';                                -- none/cursor/cursorline
  })
```

## Animation
First put all the frames so the client has them.
Then, refer to the frames by the gui widget ids to update the frame.

## TODO
- `GuiWidgetRequest` should be rpcnotify, not a function -- so it can be used in redraw.
- win_viewport does not have horizontal scroll information and sign column/number column sizes...
    - see https://github.com/neovim/neovim/pull/15674
