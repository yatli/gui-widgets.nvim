local started = false
local clientChannel = nil
local kvStore = {}
local downloads = {}
local placements = {}
local nextId=1
local namespaceId = nil
local uv = vim.loop
local Path = require'plenary.path'
local Job = require'plenary.job'
local Assert = require'luassert.assert'
local synID = vim.fn.synID
local synIDtrans = vim.fn.synIDtrans
local synIDattr = vim.fn.synIDattr


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

-- taken from plenary/path.lua, should be exposed imo..
local function _is_uri (filename)
  return string.match(filename, "^%w+://") ~= nil
end

local function _read_file(path, cb)
  -- tried plenary.async, coros don't work here yet.
  uv.fs_open(path, "r", 438, function(err, fd)
    Assert(not err, err)
    uv.fs_fstat(fd, function(err, stat)
      Assert(not err, err)
      uv.fs_read(fd, stat.size, 0, function(err, data)
        Assert(not err, err)
        uv.fs_close(fd, function(err)
          Assert(not err, err)
          cb(data)
        end)
      end)
    end)
  end)
end

local function _make_tmpfile(template, cb)
  local tmp
  if Path.path.sep == '/' then
    tmp = '/tmp'
  else
    tmp = os.getenv('TEMP')
  end
  template = tostring(Path:new(tmp) / template)
  uv.fs_mkstemp(template,function(err,fd,path)
    Assert(not err, err)
    uv.fs_close(fd, function(err)
      Assert(not err, err)
      cb(path)
    end)
  end)
end

local function _download_file(url, cb)
  local curl
  if Path.path.sep == '/' then
    curl = 'curl'
  else
    local prog = Path:new(vim.v.progpath)
    curl = tostring(prog:parent() / "curl.exe")
  end
  _make_tmpfile('gui-widgets.downloadXXXXXX',function(path)
    Job:new({
      command = curl;
      args = {url; '-o'; path};
      enable_handlers = true;
      on_exit = function(job, code, signal)
        Assert(code == 0, 'curl exited with non-zero code ' .. code)
        -- TODO check signal
        cb(path)
      end;
    }):start()
  end)
end

local function request(id)
  local val = kvStore[id]
  if clientChannel == nil or val == nil then
    return
  end

  if val.path ~= nil then
    _read_file(val.path, function(data)
      vim.rpcnotify(clientChannel, "GuiWidgetPut", {
        id = id;
        mime = val.mime;
        data = data;
      }) end)
  elseif val.data ~= nil then
    vim.rpcnotify(clientChannel, "GuiWidgetPut", {
      id = id;
      mime = val.mime;
      data = val.data;
    })
  end
end

-- param path: a path to the resource to put, can be a local file or url
-- param mime: the mime type of the resource
-- return: a non-negative integer representing the id of the resource
local function put_file(path, mime)
  local id = nextId
  nextId = nextId + 1
  local function _do_put_file(p)
    kvStore[id] = {
      path = p;
      mime = mime;
    }
    -- push it to the client right away
    request(id)
  end
  if path:find('http://', 1, true) == 1 or path:find('https://', 1, true) == 1 then
    local d = downloads[path]
    if d == nil then
      _download_file(path, function(tmp_path)
        downloads[path] = tmp_path
        _do_put_file(tmp_path)
      end)
    else
      _do_put_file(d)
    end
  else
    _do_put_file(path)
  end
  return id
end

local function put_data(data, mime)
  local id = nextId
  nextId = nextId + 1
  kvStore[id] = {
    data = data;
    mime = mime;
  }
  -- push it to the client right away
  request(id)
  return id
end


-- param id: a resource id, or an array
local function del(widgets)
  if type(widgets) ~= "table" then
    widgets = { widgets }
  end
  for _,i in pairs(widgets) do
    table.remove(kvStore, i)
  end
  vim.rpcnotify(clientChannel, "GuiWidgetDelete", widgets)
end

local function _buf(buf)
  if type(buf) == "string" then
    buf = tonumber(buf)
  elseif buf == 0 or buf == nil then
    buf = vim.api.nvim_get_current_buf()
  end

  return buf
end

-- caller ensures opt is either nil or a table
-- adds ['mouse']=true if related opts are set
local function check_mouse_opt(opt)
  if opt == nil then
    return
  end
  local has_mouse = false
  for k,v in pairs(opt) do
    if   k:find('clicked',1,true) == 1
      or k:find('released',1,true) == 1
    then
      has_mouse = true
      break
    end
  end
  if has_mouse then
    opt['mouse'] = true
  end
end

-- place non-positive id to unplace
local function place(id, bufnr, row, col, w, h, opt)
  bufnr = _buf(bufnr)
  local mark = vim.api.nvim_buf_set_extmark(bufnr, namespaceId, row, col, {})
  Assert(opt == nil or ((type(opt) == 'table') and not vim.tbl_islist(opt)), 
         'opt should be a dictionary') 
  check_mouse_opt(opt)
  -- TODO remove
  local tbl = placements[bufnr]
  if tbl == nil then
    tbl = { }
    placements[bufnr] = tbl
  end
  tbl[mark] = { id, w, h, opt }
  return mark
end

local function update_view(buf)
  if clientChannel == nil then
    return
  end
  buf = _buf(buf)
  local marks = vim.api.nvim_buf_get_extmarks(buf, namespaceId, 0, -1, {})
  local tbl = placements[buf]
  if tbl == nil then
    return
  end
  local widgets = {}
  for i,m in pairs(marks) do
    local w = tbl[m[1]]
    -- [ mark_id res_id w h, opt ]
    widgets[i] = { m[1], w[1], w[2], w[3], w[4] }
  end
  vim.rpcnotify(clientChannel, "GuiWidgetUpdateView", {
    buf = buf;
    widgets = widgets;
  })
end

-- Sample opt data:
--  {
--    ['clicked-widget']=w2;
--    ['clicked-exec']='silent call VsimToggleColor()';
--    ['released-widget']=w1;
--    ['halign']='center';
--    ['valign']='center';
--    ['stretch']='uniform';
--  }

local function mouse_event(buf, mark, ev)
  local tbl = placements[buf]
  if tbl == nil then
    return
  end
  local p = tbl[mark]
  if p == nil then
    return
  end
  local opt = p[4]
  if ev == 'down' then
    local click_exec = opt['clicked-exec']
    if click_exec ~= nil then
      vim.api.nvim_exec(click_exec, false)
    end
    local click_widget = opt['clicked-widget']
    if click_widget ~= nil then
      p[1] = click_widget
      update_view(buf)
    end
  elseif ev == 'up' then
    local release_widget = opt['released-widget']
    if release_widget ~= nil then
      p[1] = release_widget
      update_view(buf)
    end
  else
  end
end

local function mouse_up(buf, mark)
  print('mouse up ' .. buf .. ', ' .. mark)
  mouse_event(buf, mark, 'up')
end

local function mouse_down(buf, mark)
  print('mouse down ' .. buf .. ', ' .. mark)
  mouse_event(buf, mark, 'down')
end

local function clear_view(buf)
  if clientChannel == nil then
    return
  end
  buf = _buf(buf)
  local tbl = placements[buf]
  if tbl == nil then
    return
  end
  local widgets = {}
  for _, p in pairs(tbl) do
    widgets[#widgets+1] = p[1] -- widget id
  end
  del(widgets)
  placements[buf] = {}
  vim.api.nvim_buf_clear_namespace(buf, namespaceId, 0, -1)
end

local _hdr_mkd_levelRegexpDict = {
    [1] = vim.regex [[^[^:alnum:]*\(#[^#]\@=\|.\+\n\=+$\)]];
    [2] = vim.regex [[^[^:alnum:]*\(##[^#]\@=\|.\+\n-+$\)]];
    [3] = vim.regex [[^[^:alnum:]*###[^#]\@=]];
    [4] = vim.regex [[^[^:alnum:]*####[^#]\@=]];
    [5] = vim.regex [[^[^:alnum:]*#####[^#]\@=]];
    [6] = vim.regex [[^[^:alnum:]*######[^#]\@=]];
}

-- note the reversed order
local _hdr_levelRegexpDict = {
    [1] = vim.regex [[^[^:alnum:]*=[^=]\+=]];
    [2] = vim.regex [[^[^:alnum:]*==[^=]\+==]];
    [3] = vim.regex [[^[^:alnum:]*===[^=]\+===]];
    [4] = vim.regex [[^[^:alnum:]*====[^=]\+====]];
    [5] = vim.regex [[^[^:alnum:]*=====[^=]\+=====]];
    [6] = vim.regex [[^[^:alnum:]*======[^=]\+======]];
}

local _hdr_levelScaleDict = {
  [1] = 2.0;
  [2] = 1.8;
  [3] = 1.6;
  [4] = 1.2;
  [5] = 1.1;
  [6] = 1.0;
}

local _hdr_levelLineDict = {
  [1] = 2;
  [2] = 2;
  [3] = 2;
  [4] = 1;
  [5] = 1;
  [6] = 1;
}

local _img_Regexp = vim.regex '!\\[[^\\]]*\\]([^)]*)'
local _math_Regexp = vim.regex '\\$[^$]*\\$'
local _cpp_ish = { ['c']=true; ['cpp']=true; ['objc']=true; ['objcpp']=true; ['cs']=true; ['fsharp']=true; ['cuda']=true; ['asm']=true; }

-- from: https://gist.github.com/liukun/f9ce7d6d14fa45fe9b924a3eed5c3d99
local function _char_to_hex(c)
  return string.format("%%%02X", string.byte(c))
end

local function _urlencode(url)
  if url == nil then
    return
  end
  url = url:gsub("\n", "\r\n")
  url = url:gsub("([^%w ])", _char_to_hex)
  url = url:gsub(" ", "+")
  return url
end

local function refresh_buf(buf)
  if clientChannel == nil then return end
  buf = _buf(buf)
  clear_view(buf)
  local nlines = vim.api.nvim_buf_line_count(buf)
  local filetype = vim.api.nvim_buf_get_option(buf, 'filetype')
  local is_mkd = filetype == 'markdown'
  local commentstring = vim.api.nvim_buf_get_option(buf, 'commentstring')
  local hash_is_comment = (commentstring:find('#',1,true)==1)
  local cpp_ish = (_cpp_ish[filetype] ~= nil)
  local function check_pos(r,c)
    if is_mkd then return true end
    if not r or not c then return false end
    local synid = synID(r+1,c+1,1)
    synid = synIDtrans(synid)
    local name = synIDattr(synid, 'name')
    return name == 'Comment'
  end
  local function process_headers(i)
    local level,s,e
    local is_mkd_hdr = false
    if is_mkd or (not hash_is_comment and not cpp_ish) then
      for lev=1,6 do
        local regex = _hdr_mkd_levelRegexpDict[lev]
        local s__, e__ = regex:match_line(buf, i)
        if s__ ~= nil then
          s = s__
          e = e__
          level = lev
          is_mkd_hdr = true
        else
          break
        end
      end
    end
    if not level then
      for lev=1,6 do
        local regex = _hdr_levelRegexpDict[lev]
        local s__, e__ = regex:match_line(buf, i)
        if s__ ~= nil then
          s = s__
          e = e__
          level = lev
        else
          break
        end
      end
    end
    if not level or not check_pos(i,s) then
      return
    end
    local line = vim.api.nvim_buf_get_lines(buf,i,i+1,false)[1]
    local s_ = s + 1
    if is_mkd_hdr then
      s_ = line:find('#', s_, true)
      line = line:sub(s_ + level)
    else
      s_ = line:find('=', s_, true)
      line = line:sub(s_ + level, e - level)
    end
    local w = put_data(line, 'text/plain')
    local size = _hdr_levelScaleDict[level]
    local h = _hdr_levelLineDict[level]
    place(w, buf, i, s_-1, 3 * #line, h, {
      ['text-font']='Arial';
      ['text-scale']=size;
      ['text-hlid']='Normal';
      ['hide']='cursorline';
    })
  end
  local function process_imgs(i)
    local s,e = _img_Regexp:match_line(buf, i)
    if s == nil or not check_pos(i,s) then return end
    local line = vim.api.nvim_buf_get_lines(buf,i,i+1,false)[1]
    local s_ = line:find('(', s + 1, true) + 1
    local e_ = e - 1
    local path = Path:new(line:sub(s_, e_))
    if not _is_uri(tostring(path)) and not path:is_absolute() then
      local bufpath = Path:new(vim.api.nvim_buf_get_name(buf))
      path = bufpath:parent() / path
    end
    local w = put_file(tostring(path), 'image/*')
    local img_end = i
    for j=i+1,i+24 do
      local line_below = vim.api.nvim_buf_get_lines(buf,j,j+1,false)[1]
      if line_below == '' then
        img_end = j
      else
        break
      end
    end
    place(w, buf, i, s, 80, img_end - i + 1, {
      ['halign']='left';
      ['valign']='top';
      ['stretch']='uniform';
      ['hide']='cursorline';
    })
  end
  local function process_math(i)
    local s,e = _math_Regexp:match_line(buf, i)
    if s == nil or not check_pos(i, s) then return end
    local line = vim.api.nvim_buf_get_lines(buf,i,i+1,false)[1]
    local s_ = line:find('$', s + 1, true) + 1
    local e_ = e - 1
    local path = 'https://render.githubusercontent.com/render/math?math='.._urlencode(line:sub(s_, e_))
    local w = put_file(path, 'image/svg')
    place(w, buf, i, s, e - s, 1, {
      ['halign']='center';
      ['valign']='center';
      ['stretch']='uniform';
      ['hide']='cursor';
      ['svg-themed']=true;
    })
  end
  for i=0,nlines-1 do
    process_headers(i)
    process_imgs(i)
    process_math(i)
  end
  update_view(buf)
end

return {
  start = start;
  attach = attach;
  request = request;
  put_file = put_file;
  put_data = put_data;
  del = del;
  place = place;
  update_view = update_view;
  clear_view = clear_view;
  mouse_up = mouse_up;
  mouse_down = mouse_down;

  refresh_buf = refresh_buf;
}
