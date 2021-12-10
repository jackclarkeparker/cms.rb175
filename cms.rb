require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'

require 'redcarpet'
require 'yaml'
require 'bcrypt'
require 'open-uri' # Dangerous, leaves you open to remote code execution.

require 'pry'

configure do
  enable :sessions
  set :session_secret, "secret"
  set :erb, :escape_html => true
end

def redirect_if_signed_out
  if session[:username].nil?
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end
end

# View index of all documents
get "/" do
  @files = data_files
  @images = image_files
  erb :index
end

def data_files
  pattern = File.join(data_path, "*")
  Dir.glob(pattern).map do |path|
    File.basename(path)
  end
end

def data_path
  find_path_for('data')
end

def image_files
  pattern = File.join(image_path, "*")
  Dir.glob(pattern).map do |path|
    File.basename(path)
  end
end

def image_path
  find_path_for('/public/images')
end

def find_path_for(basename)
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/" + basename, __FILE__)
  else
    File.expand_path("../" + basename, __FILE__)
  end
end

# Login Portal
get "/users/signin" do
  erb :signin
end

# Credentials checked
post "/users/signin" do
  @username = params[:username]
  password = params[:password]

  if entry_credentials_valid?(@username, password)
    session[:username] = @username
    session[:message] = "Welcome!"
    redirect "/"
  else
    status 422
    session[:message] = "Invalid Credentials"
    erb :signin
  end
end

def entry_credentials_valid?(submitted_username, submitted_password)
  users = load_user_credentials

  users.any? do |user, pswd|
    user == submitted_username && BCrypt::Password.new(pswd) == submitted_password
  end
end

def load_user_credentials
  YAML.load_file(credentials_path) || {}
end

def credentials_path
  find_path_for("users.yml")
end

# Sign out of app
post "/users/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect "/"
end

# Visit Signup page
get "/users/signup" do
  erb :signup
end

# Create a new user
post "/users/create" do
  @username = params[:username].strip
  password = params[:password]
 
  if creation_credentials_valid?(@username, password)
    create_user(@username, password)
    session[:message] = "New user: #{@username} created!"
    redirect "/"
  else
    session[:message] = set_message_for_invalid_signup(@username, password)
    status 422
    erb :signup
  end
end

def creation_credentials_valid?(username, password)
  if empty_credentials?(username, password) ||
     contains_whitespace?(username, password) ||
     password_too_short?(password) ||
     username_already_in_use?(username)
    false
  else
    true
  end
end

def empty_credentials?(user, pswd)
  [user, pswd].any? { |cred| cred.empty? }
end

def contains_whitespace?(user, pswd)
  [user, pswd].any? { |cred| cred.include?(' ') }
end

def password_too_short?(password)
  password.length < 8
end

def username_already_in_use?(username)
  existing_users = load_user_credentials
  existing_users.any? { |u, _| u == username }
end

def set_message_for_invalid_signup(username, password)
  case 
  when empty_credentials?(username, password)
    "Missing either username, password, or both!"
  when contains_whitespace?(username, password)
    "Credentials cannot include spaces"
  when password_too_short?(password)
    "Password must be at least 8 characters long"
  when username_already_in_use?(username)
    "That username is already in use, please try another"
  end
end

def create_user(username, password)
  existing_users = load_user_credentials
  existing_users[username] = BCrypt::Password.create(password).to_s
  File.open(credentials_path, 'w') do |file|
    file.write(Psych.dump(existing_users))
  end
end

# Visit delete user page
get "/users/:username/delete" do
  redirect_if_signed_out

  erb :delete_user
end

# Delete current user
post "/users/:username/delete" do
  redirect_if_signed_out
  delete_user(params[:username])
  session.delete(:username)
  session[:message] = "User: #{params[:username]} has been deleted."

  redirect "/"
end

def delete_user(username)
  existing_users = load_user_credentials
  existing_users.delete(username)
  File.open(credentials_path, 'w') do |file|
    file.write(Psych.dump(existing_users))
  end
end

# View page for creating a new document
get "/documents/new" do
  redirect_if_signed_out

  erb :new_document
end

# Create a new document
post "/documents/create" do
  redirect_if_signed_out

  filename = params[:filename].strip
 
  if invalid_filename?(filename)
    session[:message] = set_message_for_invalid_filename(filename)
    status 422
    erb :new_document
  else
    file_path = File.join(data_path, filename)

    File.new(file_path, "w")
    session[:message] = "#{filename} was created!"

    redirect "/"
  end
end

def invalid_filename?(name)
  name.empty? || mismatches_pattern?(name) || already_in_use?(name)
end

def mismatches_pattern?(name)
  !name.match? /[a-z0-9\-\_]+(.txt|.md)/i
end

def already_in_use?(name)
  data_files.any? { |file| file == name }
end

def set_message_for_invalid_filename(name)
  if name.empty?
    "A name is required."
  elsif mismatches_pattern?(name)
    "Invalid filename -- Supported file types: .txt .md"
  elsif already_in_use?(name)
    "Name already in use, please assign with a unique file name."
  end
end

# View content of a document
get "/documents/:filename" do
  file_path = File.join(data_path, params[:filename])

  if File.file?(file_path)
    build_response(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
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

# Visit editing page for a document
get "/documents/:filename/edit" do
  redirect_if_signed_out

  prepare_edit_data(params[:filename])

  erb :edit
end

def prepare_edit_data(filename)
  file_path = File.join(data_path, filename)
  @filename = filename
  @content = File.read(file_path)
end

# Update a document's content
post "/documents/:filename" do
  redirect_if_signed_out

  file_path = File.join(data_path, params[:filename])
  
  process_new_content(file_path, params["new_content"])  

  redirect "/"
end

def process_new_content(file_path, new_content)
  if content_changed?(file_path, new_content)
    session[:message] = "#{File.basename(file_path)} has been updated!"
    File.write(file_path, new_content)
  end
end

def content_changed?(path, new_content)
  new_content != File.read(path)
end

# Change the name of a document
post '/documents/:filename/change_name' do
  redirect_if_signed_out

  @new_filename = params[:new_filename].strip
 
  if invalid_filename?(@new_filename)
    session[:message] = set_message_for_invalid_filename(@new_filename)
    status 422
    prepare_edit_data(params[:filename])
    erb :edit
  else
    rename_file(params[:filename], @new_filename)
    session[:message] = "File is now called #{@new_filename}!"
    redirect "/"
  end
end

def rename_file(oldname, newname)
  old_file_path = File.join(data_path, oldname)

  content = File.read(old_file_path)
  File.delete(old_file_path)

  new_file_path = File.join(data_path, newname)
  File.write(new_file_path, content)
end

# Duplicate a document
post "/documents/:filename/duplicate" do
  redirect_if_signed_out

  new_name = duplicate_name(params[:filename])
  
  new_file_path = File.join(data_path, new_name)
  old_file_path = File.join(data_path, params[:filename])

  File.write(new_file_path, File.read(old_file_path))
  session[:message] = "#{new_name} was created!"

  redirect '/'  
end

def duplicate_name(existing_file)
  files = data_files()

  basename = "copy_of_#{existing_file}"
  return basename unless files.include? (basename)

  version_number = 1

  loop do
    dup_name = basename + "(#{version_number})"
    return dup_name unless files.include? (dup_name)
    version_number += 1
  end
end

# Delete a document
post "/documents/:filename/delete" do
  redirect_if_signed_out

  file_path = File.join(data_path, params[:filename])

  File.delete(file_path)
  session[:message] = "#{params[:filename]} was deleted"

  redirect "/"
end

# Visit the 'Add Image' view
get "/images/new" do
  erb :new_image
end

# Add an image
post "/images/add" do
  imagename = params[:imagename]
  url = params[:url]

  URI.open(url) do |image|
    File.open("./public/images/#{make_jpeg(imagename)}", "wb") do |file|
      file.write(image.read)
    end
  end

  redirect "/"
end

def make_jpeg(basename)
  if basename.include?('.')
    basename[/\..*/] = '.jpg'
  else
    basename << '.jpg'
  end
end

get "/images/:imagename" do
  @path = File.join(image_path, params[:imagename])

  if File.file?(@path)
    erb :image_viewer
  else
    status 422
    session[:message] = "#{params[:imagename]} does not exist."
    redirect "/"
  end  
end