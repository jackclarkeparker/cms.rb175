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

# View page for creating a new document
get "/new" do
  erb :new
end

# Halfway to constructing a REGEX to determine that a file name is valid.
# This works, but doesn't restrict invalid characters: /.+\..+\z/

# def valid_filename?(name)
#   if name.empty?
#     session[:message] = "A name is required."
#   elsif !name.match? /./
# end

# Create a new document
post "/" do
  new_filename = params[:new_filename].strip

  if new_filename.empty?
    session[:message] = "A name is required."
    erb :new
  else
    File.new(data_path + "/#{new_filename}", "w")
    session[:message] = "#{new_filename} was created!"
    redirect "/"
  end
end

def build_response(path)
  content = File.read(path)

  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    erb markdown_to_html(content)
  end
end

def markdown_to_html(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
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
