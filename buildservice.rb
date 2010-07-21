#
# buildservice.rb
#
# A collection of classes to access openSUSE build service
#


class BuildService

private

  # extract [username, password] from ~/.oscrc
  # return nil if not possible

  def self.extract_oscrc uri
    begin
      require 'ini'
      inifile = Ini.load(File.expand_path("~/.oscrc"), :comment => '#')
      return nil unless inifile
      section = inifile["#{uri.scheme}://#{uri.host}"]
      return nil unless section
      u = section["user"]
      p = section["pass"]
      return nil unless u and p
      return [u,p]
    rescue Exception => e
      $stderr.puts "osrc failed with #{e}"
      nil
    end
  end

  # extract [username, password] from ~/.netrc
  # return nil if not possible

  def self.extract_netrc uri
    begin
      require 'net/netrc'
      rc = Net::Netrc.locate(uri.host)
      return [rc.login, rc.password]
    rescue
      nil
    end
  end

public

  require 'net/https'
  require 'nokogiri'
  
  attr_reader :uri, :user, :password, :project, :repo, :arch
  
  #
  # BuildService.new project (String), options (Hash) 
  #
  # option keys:
  #  - :api
  #  - :repo
  #  - :arch
  #  - :user
  #  - :password
  #
  def initialize(project, options)
    raise ArgumentError.new if project.nil?
    
    require 'uri'
    @uri = URI.parse(options[:api] || "https://api.opensuse.org")
    
    user = options[:user]
    password = options[:password]
    # if user/password not given, try to get them from ~/.oscrc or ~/.netrc
    if user.nil? || password.nil?
      user, password = BuildService.extract_oscrc @uri
      if user.nil? || password.nil?
        user, password = BuildService.extract_netrc @uri
	if user.nil? || password.nil?
	  raise SecurityError
	end
      end
    end
    
    @user = user
    @password = password
    @project = project
    @repo = options[:repo] || 'standard'
    @arch = options[:arch] || 'i586'

    @http = Net::HTTP.new @uri.host, @uri.port
    @http.use_ssl = (@uri.scheme == "https")
    @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
  
  def api action, url, limit=10
    raise "http redirection too deep" if limit.zero?
    c = nil
    case action.to_sym
    when :get:       c = Net::HTTP::Get
    when :put:       c = Net::HTTP::Put
    when :post:      c = Net::HTTP::Post
    when :delete:    c = Net::HTTP::Delete
    when :head:      c = Net::HTTP::Head
    when :options:   c = Net::HTTP::Options
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
	when "text/xml": xml = Nokogiri::XML(resp.body)
	when "text/html": xml = Nokogiri::HTML(resp.body)
	when "text/plain": #puts "BODY: '#{resp.body}'"
	else
	  $stderr.puts "Unknown content '#{ct}'"
      end
    end
#    $stderr.puts "Parsed #{xml.class}"
    case resp
    when Net::HTTPSuccess
      return xml
    when Net::HTTPRedirection
      return api(action, resp['location'], limit-1)
    when Net::HTTPUnauthorized
      raise "Wrong authorization"
    when Net::HTTPForbidden
      raise "Not allowed"
    else
      # FIXME: this must be easier with Nokogiri.
      if xml
	status = xml.xpath("/status/@code").first.text.to_i rescue nil
	summary = xml.xpath("/status/summary").text rescue nil
#	$stderr.puts "Status '#{status}', Summary '#{summary}'"
	raise summary if summary
      else
	raise "Unknown response #{resp}"
      end
      raise resp.to_s
    end
  end
  
  def project_config
    api :get, "/source/#{@project}/_config"
  end
  
  def buildinfo name
    # GET /build/<project>/<repository>/<arch>/<package>/_buildinfo
    api :get, "/build/#{@project}/#{@repo}/#{@arch}/#{name}/_buildinfo"
  end

  def builddepinfo
    # GET /build/<project>/<repository>/<arch>/_builddepinfo
    api :get, "/build/#{@project}/#{@repo}/#{@arch}/_builddepinfo"
  end
  
  # retrieve .solv file
  def solv
    # GET /build/<project>/<repository>/<arch>/_repository?view=solv
    api :get, "/build/#{@project}/#{@repo}/#{@arch}/_repository?view=solv"
  end

  # retrieve repository listing
  def repo
    # GET /build/<project>/<repository>/<arch>/_repository
    api :get, "/build/#{@project}/#{@repo}/#{@arch}/_repository"
  end
  
  # retrieve rpm
  def rpm name
    # GET /build/<project>/<repository>/<arch>/_repository/<name>
    api :get, "/build/#{@project}/#{@repo}/#{@arch}/_repository/#{name}"
  end
end
