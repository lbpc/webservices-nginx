local socket = require 'socket'
local os = require 'os'
local external_net_gw = os.getenv('EXTERNAL_NET_GW') or '8.8.8.8'
local internal_net_gw = os.getenv('INTERNAL_NET_GW') or '172.16.103.1'

local s = socket.udp()
s:setpeername(external_net_gw, 0)
public_ip = s:getsockname()
public_hostname = socket.dns.tohostname(public_ip)
if not public_hostname then public_hostname = socket.dns.gethostname() end
s:close()

local s = socket.udp()
s:setpeername(internal_net_gw, 0)
private_ip = s:getsockname()
private_hostname = socket.dns.tohostname(private_ip)
if not private_hostname then private_hostname = socket.dns.gethostname() end
s:close()

ngx.log(ngx.INFO, 'public IP: ' .. public_ip)
ngx.log(ngx.INFO, 'public hostname: ' .. public_hostname)
ngx.log(ngx.INFO, 'private IP: ' .. private_ip)
ngx.log(ngx.INFO, 'private hostname: ' .. private_hostname)
