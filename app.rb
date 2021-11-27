require 'sinatra'
require 'sinatra/reloader'

get "/" do
  @files = Dir.children("documents").sort
  erb :home
end
