require 'rubygems'

require 'app'
require 'spec'
require 'rack/test'

set :environment, :test

describe 'the app' do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  it "says yessir" do
    get '/'
    last_response.should be_ok
    last_response.body.should = "weloveyou"
  end

end
