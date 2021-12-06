require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'

require 'redcarpet'
require 'yaml'
require 'bcrypt'

configure do
  enable :sessions
  set :session_secret, "secret"
  set :erb, :escape_html => true
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def redirect_if_signed_out
  if session[:user].nil?
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end
end

# Login Portal
get "/users/signin" do
  erb :signin
end

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == 'test'
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
  YAML.load_file(credentials_path)
end

def valid_credentials?(submitted_username, submitted_password)
  valid_users = load_user_credentials

  valid_users.any? do |user, pswd|
    user == submitted_username && BCrypt::Password.new(pswd) == submitted_password
  end
end

# Credentials checked
post "/users/signin" do
  @username = params[:username]
  password = params[:password]

  if valid_credentials?(@username, password)
    session[:user] = @username
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid Credentials"
    status 422
    erb :signin
  end
end

# View index of all documents, or landing page if not authenticated
get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
  erb :index
end

# Sign out of app
post "/users/signout" do
  session.delete(:user)
  session[:message] = "You have been signed out."
  redirect "/"
end

# View page for creating a new document
get "/new" do
  redirect_if_signed_out

  erb :new
end

def mismatches_pattern?(name)
  !name.match? /[a-z0-9\-\_]+\.[a-z0-9\-\_]+/i
end

def invalid_filename?(name)
  name.empty? || mismatches_pattern?(name)
end

def set_message_for_invalid(name)
  if name.empty?
    "A name is required."
  elsif mismatches_pattern?(name)
    "Invalid filename _ _ _ Example correct name: `example.txt` _ _ _ Note: file must include an extension"
  end
end

# Create a new document
post "/create" do
  redirect_if_signed_out

  filename = params[:filename].strip
 
  if invalid_filename?(filename)
    session[:message] = set_message_for_invalid(filename)
    status 422
    erb :new
  else
    # Valid
    file_path = File.join(data_path, filename)

    File.new(file_path, "w")
    session[:message] = "#{filename} was created!"

    redirect "/"
  end
end

def build_response(path)
  content = File.read(path)

  case File.extname(path)
  when ".md"
    erb markdown_to_html(content)
  else #when ".txt"
    headers["Content-Type"] = "text/plain"
    content
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
  redirect_if_signed_out

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
  redirect_if_signed_out

  file_path = File.join(data_path, params[:filename])
  
  process_new_content(file_path, params["new_content"])  

  redirect "/"
end

# Delete a document
post "/:filename/delete" do
  redirect_if_signed_out

  file_path = File.join(data_path, params[:filename])

  File.delete(file_path)
  session[:message] = "#{params[:filename]} was deleted"

  redirect "/"
end
