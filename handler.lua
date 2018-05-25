local cache = require "kong.tools.database_cache"
local responses = require "kong.tools.responses"
local constants = require "kong.constants"
local singletons = require "kong.singletons"
local BasePlugin = require "kong.plugins.base_plugin"

local ngx_set_header = ngx.req.set_header
local ngx_get_headers = ngx.req.get_headers
local set_uri_args = ngx.req.set_uri_args
local get_uri_args = ngx.req.get_uri_args
local clear_header = ngx.req.clear_header
local type = type

local _realm = 'Key realm="'.._KONG._NAME..'"'
-- 引入redis模块
local redis = require "resty.redis"
-- 引入crud模块
local crud = require "kong.api.crud_helpers"
-- reports utils
local reports = require "kong.core.reports"
local utils = require "kong.tools.utils"

local KeyAuthHandler = BasePlugin:extend()

KeyAuthHandler.PRIORITY = 1000

function KeyAuthHandler:new()
  KeyAuthHandler.super.new(self, "key-auth-redis")
end

-- 连接redis方法
local function connect_to_redis(conf)
  local red = redis:new()
  red:set_timeout(conf.redis_timeout)

  local ok, err = red:connect(conf.redis_host, conf.redis_port)
  if err then
    return nil, err
  end

  if conf.redis_password and conf.redis_password ~= "" then
    local ok, err = red:auth(conf.redis_password)
    if err then
      return nil, err
    end
  end

  return red
end

local function do_authentication(conf)
  if type(conf.key_names) ~= "table" then
    ngx.log(ngx.ERR, "[key-auth-redis] no conf.key_names set, aborting plugin execution")
    return false, {status = 500, message= "Invalid plugin configuration"}
  end

  local key
  local headers = ngx_get_headers()
  local uri_args = get_uri_args()

  -- search in headers & querystring
  for i = 1, #conf.key_names do
    local name = conf.key_names[i]
    local v = headers[name]
    if not v then
      -- search in querystring
      v = uri_args[name]
    end

    if type(v) == "string" then
      key = v
      if conf.hide_credentials then
        uri_args[name] = nil
        set_uri_args(uri_args)
        clear_header(name)
      end
      break
    elseif type(v) == "table" then
      -- duplicate API key, HTTP 401 多个相同的API key请求参数
      return false, {status = 401, message = "Duplicate API key found"}
    end
  end

  -- this request is missing an API key, HTTP 401
  if not key then
    ngx.header["WWW-Authenticate"] = _realm
    return false, {status = 401, message = "No API key found in headers"
                                          .." or querystring"}
  end

  -- 先查预热缓存
  local credential, err = cache.sh_get(key)
  if err then
    return false, {status = 500, message = tostring(err)}
  end
  -- ngx.log(ngx.INFO, "预热缓存: ", credential)

  -- 如果没有，则查询redis
  if not credential then
    -- 连接redis
    local red, err = connect_to_redis(conf)
    if err then
      ngx.log(ngx.CRIT, "failed to connect to Redis: ", err)
      return false, {status = 500, message= "Failed to connect to Redis."}
    end

    -- 查询redis
    local cred, err = red:get(key)
    if not cred or cred == ngx.null or cred ~= uri_args["token"] then
      return false, {status = 403, message = "Invalid authentication credentials"}
    else
      -- ngx.log(ngx.INFO, "redis缓存: ", cred)
      -- 存cache
      -- cache.sh_set(key, 1, 31536000)
      -- ngx.log(ngx.INFO, "存cache: ", cache.get(key))
      -- redis连接池 最大空闲时间5分钟
      local keepalive_ok, err = red:set_keepalive(300000, conf.redis_connctions)
      if not keepalive_ok then
        ngx.log(ngx.CRIT, "failed to set keepalive: ", err)
      end
    end
  end
  return true
end

function KeyAuthHandler:access(conf)
  KeyAuthHandler.super.access(self)

  local ok, err = do_authentication(conf)
  if not ok then
    return responses.send(err.status, err.message)
  end

end

return KeyAuthHandler
