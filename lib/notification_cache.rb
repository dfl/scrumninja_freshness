require 'ezcrypto'
require 'base64'
require 'dalli'
require 'net/http'
require 'uri'
# require 'active_support'

class Object
  def blank?
    respond_to?(:empty?) ? empty? : !self
  end
end

class NotificationCache
  MEMCACHE_ACTION = 'memcache'

  def self.session_id= val
    @@session_id = val
  end
  def self.session_id
    @@session_id
  end

  def self.init_session req
    self.session_id = req.cookies['_scrumninja_freshness_user']
    $logger.debug "FreshnessCache.init_session with #{self.session_id}"
  end
  
  def self.init_heroku_cache
    $logger.info "initializing memcached..."
    res = Net::HTTP.start( DOMAIN ) {|http| http.get("/#{MEMCACHE_ACTION}") }
    key = EzCrypto::Key.decode "53rC4Mge+nQzRZdhBtbllQ=="
    decoded = key.decrypt( Base64.decode64( res.body ) )
    # $logger.info( decoded )
    servers, username, password = decoded.split("@")
    servers = servers.split(",")
    @@CACHE = Dalli::Client.new( servers,
        :username => username,
        :password => password )
        # :expires_in => 300)
  end

  @@retry_counter = 0
  MAX_RETRIES = 5  
  
  def self.refresh_my_view?(project_id) 
    hsh = nil
    begin
      hsh = Marshal.load( @@CACHE.get("notification_cache/#{project_id}") )
    rescue => e
      $logger.info e.to_s
      init_heroku_cache
      @@retry_counter += 1
      raise "could not connect to server!" if @@retry_counter > MAX_RETRIES
      $logger.info "retrying."
      retry
    end
    hsh ||= { :updates => [], :last_check => {} }
    $logger.info( "fetched from cache for Project #{project_id}: #{hsh.inspect}")
    if hsh[:last_check].blank? || hsh[:last_check][self.session_id].blank?
      $logger.info "true: #{@@session_id.inspect}"
      return true
    else
      hsh[:updates].each do |a|
        h = {:updated_at => a[0], :session_id => a[1], :user_id => a[2] }  # conversion shim from old array to new hash format
        return true if ( h[:updated_at] > hsh[:last_check][self.session_id] ) && h[:session_id] != self.session_id
      end
    end
    return false
  end

end