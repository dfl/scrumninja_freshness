require 'memcache'
require 'net/http'
require 'uri'
require 'activesupport'

class NotificationCache
  DOMAIN = ENV["RACK_ENV"] == "production" ? 'scrumninja.com' : 'snstaging.heroku.com'
  RAILS_ACTION = 'memcache'
  
  def self.session_id= val
    @@session_id = val
  end
  def self.session_id
    @@session_id
  end
  
  def self.init_heroku_cache
    $logger.info "initializing memcached..."
    res = Net::HTTP.start( DOMAIN ) {|http| http.get("/#{RAILS_ACTION}") }
    $logger.info( res.body )
    servers,namespace = res.body.split("@")
    servers = servers.split(",")
    $CACHE = MemCache.new(servers, :namespace => namespace)
  end

  @@retry_counter = 0
  MAX_RETRIES = 5
  
  def self.refresh_my_view?(project_id) 
    hsh = nil
    begin
      hsh = $CACHE.get("notification_cache/#{project_id}")
    rescue => e
      $logger.info e.to_s
      init_heroku_cache
      @@retry_counter += 1
      raise "could not connect to server!" if @@retry_counter > MAX_RETRIES
      $logger.info "retrying."
      retry
    end
    hsh ||= { :updates => [], :last_check => {} }
    if hsh[:last_check].blank? || hsh[:last_check][self.session_id].blank?
      return true
    else
      hsh[:updates].each do |a|
        return true if ( a[0] > hsh[:last_check][self.session_id] ) && a[1] != self.session_id
      end
    end
    return false
  end

end