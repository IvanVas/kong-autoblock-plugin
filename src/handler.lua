local plugin = require("kong.plugins.base_plugin"):extend()
local lrucache = require "resty.lrucache"
local lastUrlPerIp = lrucache.new(10000)
local counterPerIp = lrucache.new(10000)
local blockedIps = {}

plugin.PRIORITY = 100000

function plugin:new()
  plugin.super.new(self, "autoblock")
end

function plugin:init_worker()
  plugin.super.access(self)
end

function plugin:access()
  plugin.super.access(self)
	local ip = ngx.var.remote_addr
	if (blockedIps[ip]) then 
		 ngx.status = ngx.HTTP_TOO_MANY_REQUESTS
		 ngx.say("Limit exceeded")
		 ngx.exit(ngx.HTTP_TOO_MANY_REQUESTS)
	end

	local url = ngx.var.request_uri
	local counter = counterPerIp:get(ip)
	local lastUrl = lastUrlPerIp:get(ip)
      -- ngx.log(ngx.WARN, "URL: ", lastUrl)
      -- ngx.log(ngx.WARN, "counter: ", counter)
	if (lastUrl and lastUrl == url) then 
		if (not counter) then
			counter = 0
		end

		counter = counter + 1
		counterPerIp:set(ip, counter)
		if (counter > 1000) then
			blockedIps[ip] = true	
			ngx.log(ngx.WARN, "IP blocked! ", ip)
		end
	else 
		lastUrlPerIp:set(ip, url, 300)
		counterPerIp:set(ip, 0)
	end
end

return plugin
