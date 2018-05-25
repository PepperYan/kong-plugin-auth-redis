local crud = require "kong.api.crud_helpers"
local redis = require "resty.redis"
local cache = require "kong.tools.database_cache"
local responses = require "kong.tools.responses"
local singletons = require "kong.singletons"

return {
  ["/api/loadCache"] = {
    POST = function(self, helpers)
      -- ngx.log(ngx.INFO, "kong.lua loadCaches()")
      -- ngx.log(ngx.INFO, "self.perload_redis_host: ", self.params.perload_redis_host)
      -- ngx.log(ngx.INFO, "self.perload_redis_pwd: ", self.params.perload_redis_pwd)
      -- 连接redis
      local cache_red = redis:new()
      local ok, err = cache_red:connect(self.params.perload_redis_host, 6379)

      if err then
        ngx.log(ngx.ERR, "LoadCaches() failed to connect to Redis: ", err)
        return responses.HTTP_INTERNAL_SERVER_ERROR("Failed to connect to perload Redis.")
      end

      local ok, err = cache_red:auth(self.params.perload_redis_pwd)
        if err then
          ngx.log(ngx.ERR, "LoadCaches() failed to login to Redis: ", err)
          return responses.HTTP_INTERNAL_SERVER_ERROR("Failed to login to perload Redis.")
      end

      local preload_cache = cache_red:keys("*")
      -- 遍历
      for k, v in pairs(preload_cache) do
        cache.sh_set(v, 1, 31536000)
      end

      local keepalive_ok, err = cache_red:set_keepalive(300000, 100)
      if not keepalive_ok then
        ngx.log(ngx.ERR, "failed to set keepalive: ", err)
      end
      return responses.send_HTTP_OK("get perload data.")
    end
  },
  ["/consumers/:username_or_id/key-auth/"] = {
    before = function(self, dao_factory, helpers)
      crud.find_consumer_by_username_or_id(self, dao_factory, helpers)
      self.params.consumer_id = self.consumer.id
    end,

    GET = function(self, dao_factory)
      crud.paginated_set(self, dao_factory.keyauth_credentials)
    end,

    PUT = function(self, dao_factory)
      crud.put(self.params, dao_factory.keyauth_credentials)
    end,

    POST = function(self, dao_factory)
      crud.post(self.params, dao_factory.keyauth_credentials)
    end
  },
  ["/consumers/:username_or_id/key-auth/:credential_key_or_id"] = {
    before = function(self, dao_factory, helpers)
      crud.find_consumer_by_username_or_id(self, dao_factory, helpers)
      self.params.consumer_id = self.consumer.id

      local credentials, err = crud.find_by_id_or_field(
        dao_factory.keyauth_credentials,
        { consumer_id = self.params.consumer_id },
        self.params.credential_key_or_id,
        "key"
      )

      if err then
        return helpers.yield_error(err)
      elseif next(credentials) == nil then
        return helpers.responses.send_HTTP_NOT_FOUND()
      end
      self.params.credential_key_or_id = nil

      self.keyauth_credential = credentials[1]
    end,

    GET = function(self, dao_factory, helpers)
      return helpers.responses.send_HTTP_OK(self.keyauth_credential)
    end,

    PATCH = function(self, dao_factory)
      crud.patch(self.params, dao_factory.keyauth_credentials, self.keyauth_credential)
    end,

    DELETE = function(self, dao_factory)
      crud.delete(self.keyauth_credential, dao_factory.keyauth_credentials)
    end
  }
}
