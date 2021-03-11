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
  else
    local ttl = 1
	local descr = 'С вашего IP адреса зафиксирован ряд подозрительных запросов.'
    if protected then
      ttl = ngx.shared.protection_table:ttl(ngx.var.host)
	  descr = 'В данный момент сайт находится под защитой от автоматически сгенерированных запросов.'
    else
      ttl = ngx.shared.ip_filter_table:ttl(ngx.var.remote_addr)
	end
    ngx.status = ngx.HTTP_SERVICE_UNAVAILABLE
    ngx.header.Retry_After = math.floor(ttl)
    ngx.header.content_type = 'text/html'
    ngx.say(string.format([[<!DOCTYPE html><html><head><script>document.cookie='mj_anti_flood=%s;'+new Date(Date.now()+604800000).toUTCString();document.location.reload();</script><meta charset="utf-8"></head><body><p>%s Ограничение будет действовать в течение %d с.</p><p>Данная страница была отдана сервером с кодом состояния <b>HTTP 503</b> и заголовком <b>Retry-After: %d</b>, и не должна отображаться в веб-браузерах с поддержкой JavaScript.<noscript>Инструкции по включению JavaScript в популярных браузерах доступны по <a href="https://www.enable-javascript.com/ru/">этой ссылке</a>.</noscript><p>Если вы владелец сайта, дополнительную информацию вы можете узнать по e‑mail <a href="mailto:support@majordomo.ru">support@majordomo.ru</a></p></body></html>]], cookie, descr, ttl, ttl))
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
