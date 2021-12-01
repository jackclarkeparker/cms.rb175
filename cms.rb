require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'

configure do
  enable :sessions
  set :session_secret, "secret"
  set :erb, :escape_html => true
end

# root = File.expand_path("..", __FILE__)

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

# View index of all documents
get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
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
  file_path = File.join(data_path, params[:filename])

  if File.file?(file_path)
    build_response(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end  
end

# Visit editing page for a document
get "/:filename/edit" do
  file_path = File.join(data_path, params[:filename])

  @filename = params[:filename]
  @content = File.read(file_path)

  erb :edit
end

def content_changed?(path, new_content)
  new_content != File.read(path)
end

def process_new_content(file_path, new_content)
  if content_changed?(file_path, new_content)
    session[:message] = "#{File.basename(file_path)} has been updated!"
    File.write(file_path, new_content)
  end
end

# Update a document
post "/:filename" do
  file_path = File.join(data_path, params[:filename])
  
  process_new_content(file_path, params["new_content"])  

  redirect "/"
end


