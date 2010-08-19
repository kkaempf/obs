#
# buildservice.rb
#
# A collection of classes to access openSUSE build service
#
# See http://api.opensuse.org
#

module BuildService

  DEFAULT_ARGS = [
         [ "--api",      "-A", GetoptLong::REQUIRED_ARGUMENT ],
         [ "--arch",     "-a", GetoptLong::REQUIRED_ARGUMENT ],
	 [ "--user",     "-u", GetoptLong::REQUIRED_ARGUMENT ],
	 [ "--password", "-p", GetoptLong::REQUIRED_ARGUMENT ],
	 [ "--repo",     "-r", GetoptLong::REQUIRED_ARGUMENT ],
	 [ "--debug",    "-d", GetoptLong::NO_ARGUMENT ],
	 [ "--help",     "-h", GetoptLong::NO_ARGUMENT ],
	 [ "--verbose",  "-v", GetoptLong::NO_ARGUMENT ]
  ]

  def self.scanargs args, callback = nil
    res = {}
    opts = GetoptLong.new( *args )
    opts.each do |opt,arg|
      case opt
      when "--api": res[:api] = arg
      when "--arch": res[:arch] = arg
      when "--user": res[:user] = arg
      when "--format": format = arg
      when "--password": res[:password] = arg
      when "--repo": res[:repo] = arg
      when "--debug": res[:debug] = true
      when "--help": RDoc::usage
      when "--verbose": res[:verbose] = true
      else
	k,v = callback ? callback.call(opt, arg) : nil
	if k
	  res[k] = v
	else
	  $stderr.puts "Unrecognized option #{opt}"
	  return nil
	end
      end
    end

    res
  end
  
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

class Project
  require 'net/https'
  require 'nokogiri'
  
  attr_reader :uri, :user, :password, :name, :repo, :arch
  
  #
  # BuildService::Project.new name (String), options (Hash) 
  #
  # option keys:
  #  - :api
  #  - :repo
  #  - :arch
  #  - :user
  #  - :password
  #
  def initialize(project = nil, options = nil)
    unless project
      project = File.read(".osc/_project").chomp rescue nil
    end
    raise ArgumentError.new unless project
    
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
    @name = project
    @repo = options[:repo] || 'standard'
    @arch = options[:arch] || 'i586'

    @http = Net::HTTP.new @uri.host, @uri.port
    @http.use_ssl = (@uri.scheme == "https")
    @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
  
  def to_s
    @name
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
      when "text/xml", "application/xml": result = Nokogiri::XML(resp.body)
      when "text/html": result = Nokogiri::HTML(resp.body)
      when "text/plain": #puts "BODY: '#{resp.body}'"
      when "application/octet-stream": result = resp.body
      else
	$stderr.puts "Unknown content '#{ct}'"
      end
    end
#    $stderr.puts "Parsed #{xml.class}"
    case resp
    when Net::HTTPSuccess:      return result
    when Net::HTTPRedirection:  return api(action, resp['location'], limit-1)
    when Net::HTTPUnauthorized: raise "Wrong authorization"
    when Net::HTTPForbidden:    raise "Not allowed"
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

class Package
  
  attr_reader :project, :name
  def initialize project = nil, name = nil
    unless project
      project = File.read(".osc/_project").chomp rescue nil
      raise ArgumentError.new unless project
      project = BuildService::Project.new project
    end
    @project = project
    unless name
      name = File.read(".osc/_package").chomp rescue nil
      raise ArgumentError.new unless package
    end
    @name = name
  end

  def to_s
    @name
  end
  
  def buildinfo
    # GET /build/<project>/<repository>/<arch>/<package>/_buildinfo
    @project.api :get, "/build/#{@project.name}/#{@project.repo}/#{@project.arch}/#{@name}/_buildinfo"
  end

  # enumerate source files of package
  def files
    # GET /source/<project>/<package>
    xml = @project.api :get, "/source/#{@project.name}/#{@name}"
    xml.xpath("/directory/entry/@name").each do |name|
      yield
    end
  end

  def file filename
    # GET /source/<project>/<package>/<filename>
    @project.api :get, "/source/#{@project.name}/#{@name}/#{filename}"
  end

  def builddepinfo
    # GET /build/<project>/<repository>/<arch>/_builddepinfo?package="package_name"
    @project.builddepinfo @name
  end
  
end # class Package

end #Module BuildService
