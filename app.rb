# $:.unshift *Dir[File.dirname(__FILE__) + "/vendor/*/lib"]
# require 'rubygems'
require 'sinatra'
require 'logger'

Dir["./lib/*.rb"].each {|file| require file }

NotificationCache.init_heroku_cache

use Rack::Session::Cookie, :key => 'rack.session'
                           # :domain => 'foo.com',
                           # :path => '/',
                           # :expire_after => 2592000, # In seconds
                           # :secret => 'change_me'

configure do
  LOGGER = Logger.new("sinatra.log") 
end
 
helpers do
  def logger
    LOGGER
  end
end
                           
get '/notify/:project_id' do
  NotificationCache.session_id = request.env['rack.session'][:session_id]
  if NotificationCache.refresh_my_view?( params[:project_id] )
    [200, {"Content-Type" => "text/html"}, ["true"]]
  else
    [200, {"Content-Type" => "text/html"}, ["false"]]
  end
end

get '/' do
  "weloveyou."
end
