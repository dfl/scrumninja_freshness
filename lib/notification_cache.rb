require 'memcache'
require 'net/http'
require 'uri'

class NotificationCache
  CACHE_TIMEOUT = 5 * 60 # 5 minutes
  def self.session_id= val
    @@session_id = val
  end
  def self.session_id
    @@session_id
  end
  # cattr_accessor :session_id

  def self.init_heroku_cache
    domain = ENV["RACK_ENV"] == "production" ? 'scrumninja.com' : 'snstaging.heroku.com'
    res = Net::HTTP.start( domain ) {|http| http.get('/notify/memcache') }
    servers,namespace = res.body.split("@")
    servers = servers.split(",")
    $CACHE = MemCache.new(servers, :namespace => namespace)
  end

  
  # # adds an event
  # def self.add_user_event project, user_id, time=Time.now
  #   return unless self.notifications_enabled?(project)
  #   user = User.find(user_id) rescue return
  #   hsh = ( $CACHE.get project_notifier_key(project) rescue nil )
  #   hsh ||= { :updates => [], :last_check => {} }    
  #   hsh[:updates] ||= []
  #   hsh[:updates].delete_if{|a| a[2] == user.id} #remove other updates from myself
  #   update = [ time, self.session_id, user.id ]
  #   # puts "Adding user event: #{update.inspect}"
  #   hsh[:updates] << update
  #   $CACHE.set( project_notifier_key(project), hsh, CACHE_TIMEOUT ) # store for 5 minutes
  # end
  # 
  # def self.add_system_event project, time=Time.now
  #   return unless self.notifications_enabled?(project)    
  #   hsh = ( $CACHE.get project_notifier_key(project) rescue nil )
  #   hsh ||= { :updates => [], :last_check => {} }    
  #   hsh[:updates] ||= []
  #   update = [ time, "system" ]
  #   # puts "Adding system event: #{update.inspect}"
  #   hsh[:updates] << update
  #   $CACHE.set( project_notifier_key(project), hsh, CACHE_TIMEOUT ) # store for 5 minutes    
  # end
    
  def self.refresh_my_view?(project_id) 
    begin
      hsh = $CACHE.get( project_notifier_key(project_id) )
    rescue => e
      # logger.info e.to_s
      init_heroku_cache
      retry
    end
    hsh ||= { :updates => [], :last_check => {} }
    if hsh[:last_check].blank? || hsh[:last_check][self.session_id].blank?
      return true
    else
      hsh[:updates].each do |a|
        if ( a[0] > hsh[:last_check][self.session_id] ) && a[1] != self.session_id
          return true
        end
      end
    end
    return false
  end

  # # also flushes old messages
  # def self.get_event_messages_since_last_check project_id
  #   hsh = $CACHE.get( project_notifier_key(project_id) ) rescue nil
  #   hsh ||= { :updates => [], :last_check => {} }
  #   user_ids   = []
  #   delete_arr = []
  #   last_checked_time = hsh[:last_check][ self.session_id ]
  #   if hsh[:last_check].empty? || last_checked_time.nil?
  #     # forces a refresh if we haven't been connected in the last five minutes (means our last time cache expired)
  #     message = ""
  #   else
  #     # check for updates
  #     hsh[:updates].each do |ary|
  #       time,session_id,user_id = *ary
  #       
  #       if 'system' == session_id
  #         message = ""
  #       elsif time < Time.now - CACHE_TIMEOUT # delete messages that are older than 5 minutes before our time check
  #         delete_arr << ary
  #       elsif ( time > last_checked_time ) && session_id != self.session_id # find newer and not from myself
  #         # puts "Getting user event: #{ary.inspect} -- #{last_checked_time} -- I am |#{self.session_id}|"
  #         user_ids << user_id
  #       end
  #     end
  #     user_ids.uniq!
  #     if user_ids.any?
  #       conditions = []
  #       conditions << Audit.sanitize_sql_for_conditions( ["created_at >= ? AND project_id=?", last_checked_time.utc, project_id ] )
  #       conditions << Audit.sanitize_sql_for_conditions( :user_id => user_ids )
  # 
  #       audits = Audit.all( :conditions => conditions.join(" AND "), :order => "created_at DESC", :limit => 5 )
  #       if audits.any?
  #         message = audits.map(&:status_message).join("<br/>")
  #       else
  #         message = "An update has been made by the following user#{'s' if user_ids.size > 1}: #{User.find(user_ids).map(&:full_name).join(', ')}"
  #       end
  #     end
  #   end
  #   delete_arr.each{|d| hsh[:updates].delete(d) }     # remove old messages
  #   hsh[:last_check][self.session_id] = Time.now      # set last update time
  #   $CACHE.set( project_notifier_key(project_id), hsh, CACHE_TIMEOUT ) # save new message array with old items deleted for 5 another minutes    
  #   return message
  # end
  # 
  # def self.set_last_check_time(project,time=Time.now)
  #   if self.notifications_enabled?(project)
  #     hsh = $CACHE.get project_notifier_key(project) rescue nil
  #     hsh ||= {:updates =>[], :last_check=>{}}
  #     hsh[:last_check][self.session_id] = time
  #     $CACHE.set( project_notifier_key(project), hsh, CACHE_TIMEOUT )# save new message array with old items deleted    
  #   end
  #   true
  # end
  # 
  # def self.notifications_enabled?(project)
  #   project && NOTIFICATIONS_ON && (project.users.count > 1)
  # end
  # 
  # # FOR TESTING #################################
  # def self.get_last_check_time(project)
  #   hsh = $CACHE.get project_notifier_key(project) rescue return
  #   return hsh[:last_check][self.session_id]    
  # end
  # 
  # def self.flush_messages(project)
  #   $CACHE.set( project_notifier_key(project), nil, CACHE_TIMEOUT )# save new message array with old items deleted        
  # end
  #   
  ####################################  
  protected
  
  def self.project_notifier_key(project_or_id)
    project_id = (project_or_id.class == Project ? project_or_id.id : project_or_id)
    "notification_cache/#{project_id}"
  end
  
end