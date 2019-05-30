local ssl = require "ngx.ssl"
local server_name = ssl.server_name()

if server_name ~= public_hostname and server_name ~= private_hostname then
  return ngx.exit(444)
end

ssl.clear_certs()

local file_base = server_name:match("[%w%.]*%.(%w+%.%w+)") or server_name

local f = io.open("/read/ssl/" .. file_base .. ".pem", "rb")
local content = f:read("*all")
f:close()
ssl.set_cert(ssl.parse_pem_cert(content))
f = io.open("/read/ssl/" .. file_base .. ".key", "rb")
content = f:read("*all")
f:close()
ssl.set_priv_key(ssl.parse_pem_priv_key(content))
