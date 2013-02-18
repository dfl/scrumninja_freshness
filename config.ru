require 'rubygems'
require 'bundler'

Bundler.require

require './app.rb'

$logger.info "Sinatra app starting..."
run Sinatra::Application
