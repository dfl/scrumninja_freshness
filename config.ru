require 'app'

# log = File.new("log/production.log", "a+")
# $stdout.reopen(log)
# $stderr.reopen(log)

run Sinatra::Application
