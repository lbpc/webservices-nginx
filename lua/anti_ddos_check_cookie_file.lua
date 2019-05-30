if ngx.var.cookie_mj_anti_flood == ngx.md5(ngx.var.remote_addr .. ngx.var.host .. 'Pbyfblf') then
  return
end
ngx.exec('/mj-anti-flood')
