require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'

root = File.expand_path("..", __FILE__)

configure do
  set :public_folder, root + '/data'
end

get "/" do
  @files = Dir.glob(root + "/data/*").map do |path|
    File.basename(path)
  end
  erb :index
end
