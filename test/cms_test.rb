ENV["RACK_ENV"] = 'test'

require 'minitest/autorun'
require 'rack/test'

require_relative '../cms'

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
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

  def test_index
    get "/"
    
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    
    assert_includes last_response.body, "about.txt"
    assert_includes last_response.body, "changes.txt"
    assert_includes last_response.body, "history.txt"
  end


  def test_viewing_text_document
    get "/history.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "This has all happened before..."
  end

  def test_viewing_nonexistent_document
    get "/madeupfile.ext"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "madeupfile.ext does not exist."

    get "/"
    refute_includes last_response.body, "madeupfile.ext does not exist."    
  end

  def test_viewing_markdown_document
    get "/about.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
  end
end