#
# obs.rb
#
# A collection of classes to access openSUSE build service
#
# See http://api.opensuse.org
#

require 'getoptlong'

module Obs

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
      when "--api" then res[:api] = arg
      when "--arch" then res[:arch] = arg
      when "--user" then res[:user] = arg
      when "--format" then format = arg
      when "--password" then res[:password] = arg
      when "--repo" then res[:repo] = arg
      when "--debug" then res[:debug] = true
      when "--help" then RDoc::usage
      when "--verbose" then res[:verbose] = true
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

end #Module BuildService
