ENV["RACK_ENV"] = 'test'

require 'minitest/autorun'
require 'rack/test'

require 'fileutils'

require_relative '../cms'

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def session
    last_request.env["rack.session"]
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def admin_session
    { 'rack.session' => { user: 'admin' } }
  end

  def test_index
    create_document "about.md"
    create_document "changes.txt"

    get '/'
    
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
    assert_includes last_response.body, %Q(<a href="/documents/changes.txt/edit">edit)
    assert_includes last_response.body, %q(<button type="submit">Delete)
  end

  def test_index_signed_out
    get "/"
    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<a href="/users/signin">Sign In)
  end

  def test_signup_page

  end

  def test_create_new_user

  end

  def test_create_new_user__username_in_use

  end

  def test_create_new_user__password_too_short

  end

  def test_create_new_user__empty_credential

  end

  def test_create_new_user__credentials_contain_whitespace

  end  

  def test_viewing_signin_portal
    get "/users/signin"

    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<input name="username" value="">)
    assert_includes last_response.body, %q(<input name="password">)
    assert_includes last_response.body, %q(<button type="submit">Sign In)
  end

  def test_signin_with_valid_credentials
    post "/users/signin", { "username" => "admin", "password" => "secret" }

    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:message]
    assert_equal "admin", session[:user]

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin"
  end

  def test_signin_with_invalid_credentials
    post "/users/signin", { "username" => "wrong user", "password" => "" }
    
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid Credentials"
    assert_includes last_response.body, %q(<input name="username" value="wrong user">)
  end

  def test_signing_out
    post '/users/signout'

    assert_equal 302, last_response.status
    assert_nil session[:user]
    assert_equal "You have been signed out.", session[:message]
  end

  def test_viewing_text_document
    create_document "history.txt", "This has all happened before..."

    get '/documents/history.txt'

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "This has all happened before..."
  end

  def test_viewing_nonexistent_document
    get '/documents/madeupfile.ext'

    assert_equal 302, last_response.status
    assert_equal "madeupfile.ext does not exist.", session[:message]
  end

  def test_viewing_markdown_document
    create_document "about.md", "# Ruby is..."

    get '/documents/about.md'

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"
  end

  def test_new_document_page
    get '/documents/new', {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<label for="filename">Add a new document:)
    assert_includes last_response.body, %q(<button type="submit">Create)
  end

  def test_new_document_page_signed_out
    get '/documents/new'

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]

    get last_response["Location"]
    assert_includes last_response.body, "<h2>Documents</h2>"
    assert_includes last_response.body, %q(<a href="/users/signin">Sign In</a>)
  end

  def test_document_creation
    post '/documents/create', { filename: "gluben.txt" }, admin_session

    assert_equal 302, last_response.status
    assert_equal "gluben.txt was created!", session[:message]
    
    get "/"
    assert_includes last_response.body, 'href="/documents/gluben.txt"'
  end

  def test_document_creation_signed_out
    post '/documents/create', { filename: "gluben.txt" }

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]

    get last_response["Location"]
    assert_includes last_response.body, "<h2>Documents</h2>"
    assert_includes last_response.body, %q(<a href="/users/signin">Sign In</a>)
  end

  def test_document_creation_with_empty_name
    post '/documents/create', { filename: '' }, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required."
    assert_includes last_response.body, %q(<label for="filename">Add a new document:)
  end

  def test_document_creation_without_extension
    post '/documents/create', { filename: 'not_a_valid_filename' }, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid filename -- "\
                                        "Supported file types: .txt .md"
    assert_includes last_response.body, %q(<label for="filename">Add a new document:)
  end

  def test_document_creation_with_invalid_extension
    post '/documents/create', { filename: 'file.rb' }, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid filename -- "\
                                        "Supported file types: .txt .md"
    assert_includes last_response.body, %q(<label for="filename">Add a new document:)
  end

  def test_document_creation_with_duplicate_name
    create_document 'file.txt'

    post '/documents/create', { filename: 'file.txt' }, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, "Name already in use, please assign "\
                                        "with a unique file name."
    assert_includes last_response.body, %q(<label for="filename">Add a new document:)
  end

  def test_viewing_editing_page
    create_document "changes.txt"

    get '/documents/changes.txt/edit', {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<p>Edit content of changes.txt:</p>"
  end

  def test_viewing_editing_page_signed_out
    create_document "changes.txt"

    get '/documents/changes.txt/edit'

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]

    get last_response["Location"]
    assert_includes last_response.body, "<h2>Documents</h2>"
    assert_includes last_response.body, %q(<a href="/users/signin">Sign In</a>)
  end

  def test_updating_document
    create_document "changes.txt"

    post '/documents/changes.txt', { new_content: 'testing' }, admin_session

    assert_equal 302, last_response.status
    assert_equal "changes.txt has been updated!", session[:message]

    get "/documents/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "testing"
  end

  def test_updating_document_signed_out
    create_document "changes.txt"

    post '/documents/changes.txt', { new_content: 'testing' }

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]

    get last_response["Location"]
    assert_includes last_response.body, "<h2>Documents</h2>"
    assert_includes last_response.body, %q(<a href="/users/signin">Sign In</a>)
  end

  def test_rename_document
    create_document "temporary.txt"

    post "/documents/temporary.txt/change_name", { new_filename: "renamed.txt" }, admin_session
    assert_equal 302, last_response.status
    assert_equal "File is now called renamed.txt!", session[:message]

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(href="/documents/renamed.txt")
  end

  def test_rename_document_signed_out
    create_document "temporary.txt"

    post "/documents/temporary.txt/change_name", { new_filename: "renamed.txt" }
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]

    get last_response["Location"]
    assert_includes last_response.body, "<h2>Documents</h2>"
    assert_includes last_response.body, %q(<a href="/users/signin">Sign In</a>)
  end

  def test_rename_document_with_empty_name
    create_document "temporary.txt"

    post "/documents/temporary.txt/change_name", { new_filename: "" }, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required."
    assert_includes last_response.body, "<p>Edit content of temporary.txt:</p>"
  end

  def test_duplicate
    create_document "temporary.txt"

    post "/documents/temporary.txt/duplicate", {}, admin_session
    
    assert_equal 302, last_response.status
    assert_equal "copy_of_temporary.txt was created!", session[:message]

    get last_response["Location"]

    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(href="/documents/copy_of_temporary.txt")
  end

  def test_duplicate_signed_out
    create_document "temporary.txt"

    post "/documents/temporary.txt/duplicate"
    
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]

    get last_response["Location"]
    assert_includes last_response.body, "<h2>Documents</h2>"
    assert_includes last_response.body, %q(<a href="/users/signin">Sign In</a>)
  end

  def test_duplicate_2
    create_document "temporary.txt"
    create_document "copy_of_temporary.txt"
    create_document "copy_of_temporary.txt(1)"

    post "/documents/temporary.txt/duplicate", {}, admin_session
    
    assert_equal 302, last_response.status
    assert_equal "copy_of_temporary.txt(2) was created!", session[:message]

    get last_response["Location"]

    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(href="/documents/copy_of_temporary.txt(2)")
  end

  def test_document_deletion
    create_document "temporary.txt"

    get '/', {}, admin_session

    assert_includes last_response.body, 'href="/documents/temporary.txt"'

    post "/documents/temporary.txt/delete"
    assert_equal 302, last_response.status
    assert_equal "temporary.txt was deleted", session[:message]

    get "/"
    refute_includes last_response.body, 'href="/documents/temporary.txt"'
  end

  def test_document_deletion_signed_out
    create_document "temporary.txt"

    get '/'

    assert_includes last_response.body, 'href="/documents/temporary.txt"'

    post "/documents/temporary.txt/delete"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]

    get last_response["Location"]
    assert_includes last_response.body, "<h2>Documents</h2>"
    assert_includes last_response.body, %q(<a href="/users/signin">Sign In</a>)
  end
end

=begin

MY ORIGINAL TESTS

  def setup
    @root = File.expand_path('../..', __FILE__)
    @file_paths = Dir.glob(@root + "/data/*")
  end

  def test_index
    get "/"
    assert_equal 200, last_response.status
    # Headers
      # Content-Type is what they tested for before. Anything else?
      # When I run `headers` in sinatra, it shows that only one response
      # header is already accessible, but presumably others are also used.
      
      # Yeah. Maybe a location would be good to check with a redirect?

      # I've just looked at the response headers included when we load the
      # index. There aren't many. There is Content-Length?
      # There's also a few X-**** response headers that I've never heard of.
      # For now, I suppose I'll stick to
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
  
    # Body

    # Do we hard code the files that we've been told we'll work with?
    # Do we test component of the body, rather than the body in full?
    
      #   Actually a combination of these two ^^
      #     We want to hardcode literals into our tests so that we don't leave
      #     room for a misinterpretation of how code works to filter into our
      #     tests, such that they suggest they're working, when in reality they
      #     are not. VERY difficult to squash that bug.

    # Plan is this -> Put this aside for now, these questions are alive.
    # Instead, go take a look at the other test, and then once you've tinkered
    # there as well, compare notes with the implementation suggestions.
    
    file_names = @file_paths.map { |path| File.basename(path) }
    assert file_names.all? { |file| last_response.body.include? file }
  end

  def test_viewing_text_document # || test_files || test_file
    # Question of, do we hard code each file explicitly in this test method?
    # Do we carry out preparation first? We kind of need to if we're issuing
    # a request to a random route. If we are hardcoding the routes, then we
    # won't need to do any prep.
    # Maybe we do it hardcoded now?
    # Maybe we test the idea of doing prep first, and see if that works?
    # Then hardcode?
    @file_paths.each do |path|
      route = File.basename(path)

      get "/#{route}"
      assert_equal 200, last_response.status
      assert_equal "text/plain", last_response["Content-Type"]
      # assert(last_response.body.include? File.read(path))
      assert_includes last_response.body, File.read(path)
    end
  end


=end
