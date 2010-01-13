$:.unshift *Dir[File.dirname(__FILE__) + "/vendor/*/lib"]

require 'rubygems'
require 'sinatra'

RACK_ENV = ENV['RACK_ENV'] || 'staging'
DOMAIN = ENV["RACK_ENV"] == "production" ? 'scrumninja.com' : 'snstaging.heroku.com'
require 'logger'
$logger = Logger.new("log/#{RACK_ENV}.log")

Dir["./lib/*.rb"].each {|file| require file }

require 'newrelic_rpm'

NotificationCache.init_heroku_cache

helpers do
  def output val, status=200, type="text/html"
    [ status, {"Content-Type" => type }, [ val ] ]
  end  
  
  def jsonp val, key=:callback
    params[key]+"(#{val})"
  end
end
   
get '/notify/:project_id' do
  NotificationCache.session_id = request.cookies["_scrum_ninja_session"].hash.to_s(36)
  return output("callback required", 500) unless params[:callback]
  result = NotificationCache.refresh_my_view?( params[:project_id] )  #  rand(2) == 0 ? true : false
  output jsonp( result )
end

get '/' do
  "weloveyou."
end
