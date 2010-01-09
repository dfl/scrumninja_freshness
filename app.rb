# $:.unshift *Dir[File.dirname(__FILE__) + "/vendor/*/lib"]
require 'rubygems'
require 'sinatra'
require 'logger'

RACK_ENV = ENV['RACK_ENV'] || 'staging'
$logger = Logger.new("log/#{RACK_ENV}.log")

Dir["./lib/*.rb"].each {|file| require file }


NotificationCache.init_heroku_cache

use Rack::Session::Cookie, :key => 'rack.session'
                           # :domain => 'foo.com',
                           # :path => '/',
                           # :expire_after => 2592000, # In seconds
                           # :secret => 'change_me'


helpers do
  def output val, status=200, type="text/html"
    [ status, {"Content-Type" => type }, [ val ] ]
  end  
  
  def jsonp val, key=:callback
    params[key]+"(#{val})"
  end
end
   
get '/notify/:project_id' do
  NotificationCache.session_id = request.env['rack.session'][:session_id]
  return output("callback required", 500) unless params[:callback] #
  result = NotificationCache.refresh_my_view?( params[:project_id] )  #  rand(2) == 0 ? true : false
  output jsonp( result )
end

get '/' do
  "weloveyou."
end
