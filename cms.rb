require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'

configure do
  enable :sessions
  set :session_secret, "secret"
  set :erb, :escape_html => true
end

root = File.expand_path("..", __FILE__)

get "/" do
  @files = Dir.glob(root + "/data/*").map do |path|
    File.basename(path)
  end
  erb :index
end

get "/:filename" do
  file_path = root + "/data/" + params[:filename]

  if !File.file?(file_path)
    session[:error] = "#{params[:filename]} does not exist."
    redirect "/"
  elsif File.extname(file_path) == ".md"
    markdown_to_html = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    markdown_to_html.render(File.read(file_path))
  else
    headers["Content-Type"] = "text/plain"
    File.read(file_path)
  end  
end
