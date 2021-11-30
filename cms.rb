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

# View index of all documents
get "/" do
  @files = Dir.glob(root + "/data/*").map do |path|
    File.basename(path)
  end
  erb :index
end

def markdown_to_html(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def build_response(path)
  content = File.read(path)

  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    markdown_to_html(content)
  end
end

# View content of a document
get "/:filename" do
  @file_path = root + "/data/" + params[:filename]

  if File.file?(@file_path)
    build_response(@file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end  
end

# Visit editing page for a document
get "/:filename/edit" do
  @filename = params[:filename]
  @file_path = root + "/data/" + @filename

  erb :edit
end

def content_changed?(path, new_content)
  new_content != File.read(path)
end

# Update a document
post "/:filename" do
  @filename = params[:filename]
  @file_path = root + "/data/" + @filename

  if content_changed?(@file_path, params["new_content"])
    File.write(@file_path, params["new_content"])
    session[:message] = "#{@filename} has been updated!"
  end

  redirect "/"
end


