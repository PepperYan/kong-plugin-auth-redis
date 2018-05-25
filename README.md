# kong-plugin-auth-redis/ key-auth-redis
This is a kong plugin tested under 300,000 rps circumstance.
经受十万级别并发请求的权限认证组件

## 简介
key-auth with redis

## 功能
1. 可连接单个redis；
2. 根据redis查询得到key(token)；
3. 保存key到kong本地数据库；(取消)

### 备选功能
1. 为每一个consumer创建一个rate-limiting插件以限制用户的访问速率；

## 使用步骤
1. 通过`kong api`或者`kong dashboard`，为指定API注册插件`key-auth-redis`
2. 设置相应的配置

| 名称 | 类型 | 默认值  | 说明 |
| ----------- | --------- | --- | --- |
| key_names | string | function   |自定义api_key的名称（一般设为token）|
| hide_credentials | boolean |false   |一个可选的布尔值，指示插件将凭据隐藏到上游API服务器。在代理请求之前，它将被Kong删除。|
| anonymous | string |  \`\` |如果身份验证失败，则可以使用可选的字符串（消费者uuid）值作为“匿名”消费者。如果为空（默认），则请求将失败并发送身份验证失败4xx |
| redis_host | string | \`\`  |redis服务器IP地址（必须）|
| redis_port | number | 6379  |redis服务器端口|
| redis_password | string | \`\`  |redis密码|
| redis_timeout | number | 2000  |redis超时时间（ms）|
| rate_limiting | boolean | false  |指定是否在创建consumer的同时，创建与其相关的rate_limiting插件|
| apiname_uri_lastest | boolean | false  |指定rate-limiting插件所作用的api_name为consumer访问的uri的最后一段字符串。例如uri是`/key/auth/redis`，则api\_name=redis|
| limit_by | string | consumer  |根据类型限制访问速率，类型有`consumer`, `credential`, `ip`|
| policy | string | cluster  |根据策略配置rate-limiting计数器，策略类型有`local`, `cluster`, `redis`|
| fault_tolerant | boolean | true  |用于确定请求是否应被代理，即使Kong连接第三方数据存储时遇到问题。如果真正的请求将被代理，无论如何有效地禁用速率限制功能，直到数据存储再次工作。如果为false，那么客户端将看到500错误。|
| redis_database | number | 0  |redis数据库个数，当只有一个数据库时，只需采用默认值0|
| second | number | 无  |从第一次访问算起，一秒限制的次数|
| minute | number | 无  |从第一次访问算起，一分钟限制的次数|
| hour | number | 无  |从第一次访问算起，一小时限制的次数|
| day | number | 无  |从第一次访问算起，一天内限制的次数|
| month | number | 无  |从第一次访问算起，一个月内限制的次数|
| year | number | 无  |从第一次访问算起，一年内限制的次数|

3. 配置设置成功后，启用插件便能够生效。

