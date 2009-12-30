require 'memcache'

servers   = %w[10.245.227.175:11211 10.245.85.220:11211]
namespace = "00ec9267174f" #  staging
# namespace = "3baad172ee0b" # production
CACHE = MemCache.new(servers, :namespace => namespace)

require 'app'
run Sinatra::Application


