require 'rubygems'
require 'bundler'

Bundler.require

require './app.rb'

$stdout.sync = true
$logger.info "Sinatra app starting..."
run Sinatra::Application
