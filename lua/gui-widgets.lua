Started = false
ProcId = -1
ClientChannel = nil
KvStore = {}
NextId=1

local uv = vim.loop

local function start()
  if Started then
    return
  end
  Started = true
end

local function attach(chan)
  ClientChannel = chan
end

local function request(id)
  local val = KvStore[id]
  if ClientChannel == nil or val == nil then
    vim.cmd("echo 'not really'")
    return
  end

  uv.fs_open(val.path, "r", 438, function(err, fd)
    assert(not err, err)
    uv.fs_fstat(fd, function(err, stat)
      assert(not err, err)
      uv.fs_read(fd, stat.size, 0, function(err, data)
        assert(not err, err)
        vim.rpcnotify(ClientChannel, "GuiWidgetPut", {
          id = id;
          mime = val.mime;
          data = data;
          stat_size = stat.size;
          str_len = string.len(data);
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
  local id = NextId
  NextId = NextId + 1
  -- maybe copy path to tmpfs for immutability?
  KvStore[id] = {
    path = path;
    mime = mime;
  }
  -- push it to the client right away
  request(id)
  return id
end

-- param id: a resource id
-- param id: a resource id
local function del(id)
end

-- place negative id to unplace
local function place(id, bufnr, row, col)
end

return {
  start = start;
  attach = attach;
  request = request;
  put = put;
  del = del;
  place = place;
}
