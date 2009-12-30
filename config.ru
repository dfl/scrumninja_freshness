require 'memcache'
servers   = %w[10.245.227.175:11211 10.245.85.220:11211] #ENV['MEMCACHE_SERVERS'].split(',')
namespace = "3baad172ee0b" #ENV['MEMCACHE_NAMESPACE']
CACHE = MemCache.new(servers, :namespace => namespace)

require 'app'
run Sinatra::Application


