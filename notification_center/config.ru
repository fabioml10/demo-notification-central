require_relative "./app"
require 'sinatra'
require 'rack/protection'

set :environment, :development

use Rack::Protection
run Sinatra::Application
