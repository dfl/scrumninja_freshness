# $:.unshift *Dir[File.dirname(__FILE__) + "/vendor/*/lib"]
# require 'rubygems'
require 'sinatra'

Dir["./lib/*.rb"].each {|file| require file }

get '/:project_id' do
  NotificationCache.session_id = request.env['rack.session'][:session_id]
  if NotificationCache.refresh_my_view?( params[:project_id] )
    [200, {"Content-Type" => "text/html"}, ["true"]]
  else
    [200, {"Content-Type" => "text/html"}, ["false"]]
  end
else
  [404, {"Content-Type" => "text/html"}, ["Not Found"]]
end

get '/' do
  "weloveyou."
end
