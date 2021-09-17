local started = false
local clientChannel = nil
local kvStore = {}
local placements = {}
local nextId=1
local namespaceId = nil
local uv = vim.loop

local function start()
  if started then
    return
  end
  namespaceId = vim.api.nvim_create_namespace("GuiWidget")
  started = true
end

local function attach(chan)
  clientChannel = chan
end

local function request(id)
  local val = kvStore[id]
  if clientChannel == nil or val == nil then
    vim.cmd("echo 'not really'")
    return
  end

  -- tried plenary.async, coros don't work here yet.
  uv.fs_open(val.path, "r", 438, function(err, fd)
    assert(not err, err)
    uv.fs_fstat(fd, function(err, stat)
      assert(not err, err)
      uv.fs_read(fd, stat.size, 0, function(err, data)
        assert(not err, err)
        vim.rpcnotify(clientChannel, "GuiWidgetPut", {
          id = id;
          mime = val.mime;
          data = data;
        })
        uv.fs_close(fd, function(err)
          assert(not err, err)
        end)
      end)
    end)
  end)
end

-- param path: a path to the resource to put
-- param mime: the mime type of the resource
-- return: a non-negative integer representing the id of the resource
local function put(path, mime)
  local id = nextId
  nextId = nextId + 1
  -- maybe copy path to tmpfs for immutability?
  kvStore[id] = {
    path = path;
    mime = mime;
  }
  -- push it to the client right away
  request(id)
  return id
end

-- param id: a resource id
local function del(id)
end

-- place non-positive id to unplace
local function place(id, bufnr, row, col, w, h)
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  local mark = vim.api.nvim_buf_set_extmark(bufnr, namespaceId, row, col, {})
  -- TODO remove
  local tbl = placements[bufnr]
  if tbl == nil then
    tbl = { }
    placements[bufnr] = tbl
  end
  tbl[mark] = { id, w, h }
  return mark
end

local function update_view(buf)
  if clientChannel == nil then
    return
  end
  if type(buf) == "string" then
    buf = tonumber(buf)
  elseif buf == nil or buf == 0 then
    buf = vim.api.nvim_get_current_buf()
  end
  local marks = vim.api.nvim_buf_get_extmarks(buf, namespaceId, 0, -1, {})
  local tbl = placements[buf]
  if tbl == nil then
    return
  end
  local widgets = {}
  for i,m in pairs(marks) do
    local w = tbl[m[1]]
    -- [ mark_id res_id w h ]
    -- TODO display attributes (e.g. alignment)
    widgets[i] = { m[1], w[1], w[2], w[3] }
  end
  vim.rpcnotify(clientChannel, "GuiWidgetUpdateView", {
    buf = buf;
    widgets = widgets;
  })
end

return {
  start = start;
  attach = attach;
  request = request;
  put = put;
  del = del;
  place = place;
  update_view = update_view;
}
