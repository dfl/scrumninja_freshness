require 'rubygems'
require 'sinatra'

ENV['APP_ROOT'] ||= File.dirname(__FILE__)
RACK_ENV = ENV['RACK_ENV'] || 'staging'
DOMAIN = ENV["RACK_ENV"] == "production" ? 'scrumninja.com' : 'snstaging.heroku.com'
require 'logger'
$logger = Logger.new("log/#{RACK_ENV}.log")

configure :production do
  require 'newrelic_rpm'
end

Dir["#{ENV['APP_ROOT']}/lib/*.rb"].each {|file| require file }


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
  $logger.info "initializing from metal #{p request.cookies}"
  NotificationCache.init_session( request )
  return output("callback required", 500) unless params[:callback]
  result = NotificationCache.refresh_my_view?( params[:project_id] )  #  rand(2) == 0 ? true : false
  output jsonp( result )
end

get '/' do
  "weloveyou."
end
