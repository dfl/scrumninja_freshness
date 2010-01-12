# $:.unshift *Dir[File.dirname(__FILE__) + "/vendor/*/lib"]
require 'rubygems'
require 'sinatra'
require 'logger'

RACK_ENV = ENV['RACK_ENV'] || 'staging'
DOMAIN = ENV["RACK_ENV"] == "production" ? 'scrumninja.com' : 'snstaging.heroku.com'

$logger = Logger.new("log/#{RACK_ENV}.log")

Dir["./lib/*.rb"].each {|file| require file }


NotificationCache.init_heroku_cache


use Rack::Session::Cookie, :key         => '_scrum_ninja_session',
                           :domain      => DOMAIN,
                           :secret      => 'b571fb81bac0c6d9a083d54816a44251e8b3a0e5631b54b23983b49660435284a618d805bdd8105f9358853c1e31be2d9da0540959b0fc3ff57eac867654adc6'


helpers do
  def output val, status=200, type="text/html"
    [ status, {"Content-Type" => type }, [ val ] ]
  end  
  
  def jsonp val, key=:callback
    params[key]+"(#{val})"
  end
end
   
get '/notify/:project_id' do
  NotificationCache.session_id = env['rack.session'][:session_id] #request.cookies["_scrum_ninja_session"].session_id
  return output("callback required", 500) unless params[:callback]
  result = NotificationCache.refresh_my_view?( params[:project_id] )  #  rand(2) == 0 ? true : false
  output jsonp( result )
end

get '/' do
  "weloveyou."
end
