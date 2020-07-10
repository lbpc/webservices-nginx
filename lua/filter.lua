if not ngx.re.find(ngx.req.get_method(), '^(GET|POST|HEAD|PUT|DELETE|CONNECT|OPTIONS|TRACE|PATCH|PROPFIND|PROPPATCH|MKCOL|MOVE|LOCK|UNLOCK)$', 'io') then
  ngx.status = ngx.HTTP_NOT_ALLOWED
  ngx.header['Allow'] = 'GET, POST, HEAD, PUT, DELETE, CONNECT, OPTIONS, TRACE, PATCH, PROPFIND, PROPPATCH, MKCOL, MOVE, LOCK, UNLOCK'
  ngx.header.content_type = 'text/plain'
  ngx.say("This method is not allowed here, it's a shared hosting server")
  ngx.exit(ngx.HTTP_OK)
end

local act = ngx.shared.ip_filter_table:get(ngx.var.remote_addr)
local protected = ngx.shared.protection_table:get(ngx.var.host)
local matched = ngx.var.header_filter_iregex and ngx.re.find(ngx.var.request_uri .. (ngx.req.get_headers()['User-Agent'] or ''), ngx.var.header_filter_iregex, 'sio')

if protected then act = 0 end

if not act and not matched then
  return
else
  act = act or 0
  ngx.var.filter_passed = 0 
  ngx.var.filter_action = act
  ngx.var.filter_reason = matched and 'regex' or (protected and 'host' or 'ip')
end

if act == 0 then
  local str_to_hash = ngx.var.remote_addr .. ngx.var.host .. 'Pbyfblf'
  local cookie = ngx.md5(str_to_hash)
  if ngx.var.cookie_mj_anti_flood == cookie then
    ngx.var.filter_passed = 1 
    return
  elseif ngx.var.uri == '/robots.txt' then
    ngx.say('User-agent: *\nDisallow: /')
    ngx.exit(ngx.HTTP_OK)
  else
    ngx.header.content_type = 'text/html'
    ngx.say(string.format([[<html><body onload="document.cookie='mj_anti_flood=%s;'+new Date(Date.now()+604800000).toUTCString();document.location.reload();"></body></html>]], cookie))
    ngx.exit(ngx.HTTP_OK)
  end
elseif act == 1 then
  ngx.status = ngx.HTTP_FORBIDDEN
  ngx.header.content_type = 'text/html'
  ngx.print(ngx.location.capture('/http_403.html').body)
  ngx.exit(ngx.HTTP_OK)
elseif act == 2 then 
  ngx.exit(444)
end
