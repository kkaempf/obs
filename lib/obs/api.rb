#
# api.rb
#
# A collection of classes to access openSUSE build service
#
# See http://api.opensuse.org
#

module Obs

class Api
  require 'net/https'
  require 'nokogiri'
  
  attr_reader :uri, :user, :password
  
  #
  # Obs::Api.new options (Hash) 
  #
  # option keys:
  #  - :api
  #  - :user
  #  - :password
  #
  def initialize(options = nil)
    api = options[:api]
    unless api
      api = File.read(".osc/_apiurl").chomp rescue nil
    end

    require 'uri'
    @uri = URI.parse(api || "https://api.opensuse.org")
    
    user = options[:user]
    password = options[:password]
    # if user/password not given, try to get them from ~/.oscrc or ~/.netrc
    if user.nil? || password.nil?
      user, password = Obs.extract_oscrc @uri
      if user.nil? || password.nil?
        user, password = Obs.extract_netrc @uri
	if user.nil? || password.nil?
	  raise SecurityError
	end
      end
    end
    
    @user = user
    @password = password

    @http = Net::HTTP.new @uri.host, @uri.port
    @http.use_ssl = (@uri.scheme == "https")
    @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
  
  def to_s
    @uri.to_s
  end
  
  def head url, limit=10
    api :head, url, limit
  end

  def get url, limit=10
    api :get, url, limit
  end

  def get url, limit=10
    api :get, url, limit
  end

  def delete url, limit=10
    api :delete, url, limit
  end

  def api action, url, limit=10
    raise "http redirection too deep" if limit.zero?
    c = nil
    case action.to_sym
    when :get then     c = Net::HTTP::Get
    when :put then     c = Net::HTTP::Put
    when :post then    c = Net::HTTP::Post
    when :delete then  c = Net::HTTP::Delete
    when :head then    c = Net::HTTP::Head
    when :options then c = Net::HTTP::Options
    else
      raise "Unknown action #{action}"
    end
    req = c.new url
    req.initialize_http_header({"Accept" => "*/*"})
    req.basic_auth(@user, @password)
    @http.start unless @http.started?
    resp = @http.request( req )
    
    raise "Cannot connect to #{url}" unless resp
#    $stderr.puts "Connected to #{url}"
    xml = nil
    if resp.body
      ct = resp['content-type'].split(';').first # split off ';charset ...'
#      $stderr.puts "Received #{ct}"
      case ct
      when "text/xml", "application/xml"
        result = Nokogiri::XML(resp.body)
      when "text/html"
        result = Nokogiri::HTML(resp.body)
      when "text/plain"
        #puts "BODY: '#{resp.body}'"
      when "application/octet-stream"
        result = resp.body
      else
	$stderr.puts "Unknown content '#{ct}'"
      end
    end
#    $stderr.puts "Parsed #{xml.class}"
    case resp
    when Net::HTTPSuccess then      return result
    when Net::HTTPRedirection then  return api(action, resp['location'], limit-1)
    when Net::HTTPUnauthorized then raise "Wrong authorization"
    when Net::HTTPForbidden then    raise "Not allowed"
    else
      # FIXME: this must be easier with Nokogiri.
      if result
	status = result.xpath("/status/@code").first.text.to_i rescue nil
	summary = result.xpath("/status/summary").text rescue nil
#	$stderr.puts "Status '#{status}', Summary '#{summary}'"
	raise summary if summary
      else
	raise "Unknown response #{resp}"
      end
      raise resp.to_s
    end
    nil
  end
  
  def exists?
    # check access to OBS

    begin
      resp = api :get, "/"
    rescue Exception => e
      $stderr.puts "Could not access obs server at #{@uri}: #{e}"
      return false
    end
    # verify existance of project

    begin
      meta
    rescue Exception => e
      $stderr.puts "Could not access project #{@name}: #{e}"
      return false
    end
    true
  end

  def config
    api :get, "/source/#{@name}/_config"
  end
  
  def meta
    api :get, "/source/#{@name}/_meta"
  end
  
  def pattern
    api :get, "/source/#{@name}/_pattern"
  end
  
  def builddepinfo name = nil
    # GET /build/<project>/<repository>/<arch>/_builddepinfo
    api :get, "/build/#{@name}/#{@repo}/#{@arch}/_builddepinfo" + (name ? "" : "?package=\"#{name}\"")
  end
  
  # retrieve .solv file
  def solv
    # GET /build/<project>/<repository>/<arch>/_repository?view=solv
    api :get, "/build/#{@name}/#{@repo}/#{@arch}/_repository?view=solv"
  end

  # retrieve repository listing
  def repository
    # GET /build/<project>/<repository>/<arch>/_repository
    api :get, "/build/#{@name}/#{@repo}/#{@arch}/_repository"
  end
  
  # retrieve rpm
  def rpm name
    # GET /build/<project>/<repository>/<arch>/_repository/<name>
    api :get, "/build/#{@name}/#{@repo}/#{@arch}/_repository/#{name}"
  end

  # enumerat packages in this project
  def packages
    # GET /source/<project>
    xml = api :get, "/source/#{@name}"
    xml.xpath("/directory/entry/@name").each do |name|
      yield name
    end
  end


end # class Project

end #Module Obs
