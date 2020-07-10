require "resty.core"
local math = require "math"
local protection_table = ngx.shared.protection_table
local method = ngx.req.get_method()
local _, host = ngx.var.uri:match("/(.-)/(.+)")
local auth_token = "w5iwLomy2okyHDFLUiTimSuk84VLtY70pfiI"


ngx.header.content_type = "text/plain"


if method == "GET" then
    local res = nil
    if host then
        res = protection_table:get(host)
    else
        res = protection_table:get_keys(0)
    end
    if type(res) == "table" then
        for _, host in pairs(res) do
            local ttl = protection_table:ttl(host)
            ngx.say(host .. " " .. math.floor(ttl))
        end
    elseif res then
        local ttl = protection_table:ttl(host)
        ngx.say(math.floor(ttl))
    else
        ngx.status = ngx.HTTP_NOT_FOUND
    end
    ngx.exit(ngx.HTTP_OK)
elseif method == "DELETE" then
    protection_table:delete(host)
    ngx.log(ngx.WARN, host .. " removed from protection set")
    ngx.exit(ngx.HTTP_OK)
elseif method == "PUT" then
    local ok, allow, msg = true, true, nil
    local args, _ = ngx.req.get_uri_args()
    local ttl = args["ttl"] or 600
    ttl = tonumber(ttl)
    if not ttl then
        ok, msg = false, "ttl must be a number"
    elseif ttl ~= math.floor(ttl) then
        ok, msg = false, "ttl must be an integer"
    end
    local req_auth_token = ngx.req.get_headers()["Authorization"]
    if ttl and (ttl < 1 or ttl > 7200) and req_auth_token ~= auth_token then
        allow, msg = false, "setting ttl above 7200 or 0 requires authorization"
    end
    if not ok then
        ngx.status = ngx.HTTP_BAD_REQUEST
        ngx.say(msg)
    elseif not allow then
        ngx.status = ngx.HTTP_UNAUTHORIZED
        ngx.say(msg)
    else
        protection_table:set(host, 1, ttl)
        ngx.log(ngx.WARN, host .. " added to protection set for " .. ttl .. " seconds")
    end
    ngx.exit(ngx.HTTP_OK)
else
    ngx.status = ngx.HTTP_NOT_ALLOWED
    ngx.say(method .. " is not allowed here")
    ngx.exit(ngx.HTTP_OK)
end

