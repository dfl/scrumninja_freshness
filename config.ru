require 'memcache'
servers   = ENV['MEMCACHE_SERVERS'].split(',')
namespace = ENV['MEMCACHE_NAMESPACE']
CACHE = MemCache.new(servers, :namespace => namespace)

require 'app'
run Sinatra::Application


