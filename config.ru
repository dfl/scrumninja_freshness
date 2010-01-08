require 'app'

log = File.new("log/#{ENV['RACK_ENV']}.log", "a+")
$stdout.reopen(log)
$stderr.reopen(log)

run Sinatra::Application
