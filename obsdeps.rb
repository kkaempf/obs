#!/usr/bin/ruby
#
# == Synopsis
#
# obsdeps.rb - visualize _o_pensuse _b_uild _s_service _dep_endencie_s_
#
# == Usage
#
# obsdeps [-A <apiurl>] [-u <user>] [-p <password>] [-f format] <project> [ <repo> [ <arch> ] ]
#
# <project>:
#   project name
#
# <repo>:
#   repository name, defaults to 'standard'
#
# <arch>:
#   architecture, defaults to 'i586'
#
# -A <api>, --api <api>:
#   build service api, defaults to https://api.suse.de
#
# -u <user>, --user <user>:
#   username to access build service through <api>
#
# -p <password>, --password <password>:
#   password matching username
#
# -d, --debug:
#   enable debug
#
# -h, --help:
#   give help
#
# -v, --verbose
#   be verbose
#
# -f <format>, --format <format>:
#   output format, either 'tlp' or 'dot'
#
#
# Note:
# obsdeps tries to extract username and password either from ~/.oscrc
# or from ~/.netrc if the respective gems are installed.
# Support for ~/.oscrc requires rubygem-ini, support for ~/.netrc
# requires rubygem-net-netrc
#
#

require 'rubygems'
require 'getoptlong'
require 'rdoc/usage'
require 'buildservice'

opts = GetoptLong.new(
	 [ "--api",      "-A", GetoptLong::REQUIRED_ARGUMENT ],
	 [ "--format",   "-f", GetoptLong::REQUIRED_ARGUMENT ],
	 [ "--user",     "-u", GetoptLong::REQUIRED_ARGUMENT ],
	 [ "--password", "-p", GetoptLong::REQUIRED_ARGUMENT ],
	 [ "--debug",    "-d", GetoptLong::NO_ARGUMENT ],
	 [ "--help",     "-h", GetoptLong::NO_ARGUMENT ],
	 [ "--verbose",  "-v", GetoptLong::NO_ARGUMENT ]
)

format = nil

user = password = api = nil
opts.each do |opt,arg|
  case opt
  when "--api": api = arg
  when "--user": user = arg
  when "--format": format = arg
  when "--password": password = arg
  when "--debug": debug = true
  when "--help": RDoc::usage
  when "--verbose": verbose = true
  else
    $stderr.puts "Unrecognized option #{opt}"
    RDoc::usage
  end
end

project = ARGV.shift
repo = ARGV.shift
arch = ARGV.shift

obs = begin
  BuildService.new project, :user => user, :password => password, :api => api, :repo => repo, :arch => arch
rescue ArgumentError
  $stderr.puts "No project given"
  RDoc::usage
rescue SecurityError
  $stderr.puts "Please provide username and password"
  RDoc::usage
end

# check access to OBS

begin
  resp = obs.api :get, "/"
rescue Exception => e
  $stderr.puts "Could not access obs server at #{obs.uri}: #{e}"
  exit 1
end

begin
  # verify existance of project

  obs.project_config

  # get buildepinfo

  xml = obs.builddepinfo

  unless xml.is_a? Nokogiri::XML::Document
    $stderr.puts "Unexpected output #{xml.class}"
    exit 1
  end

  packages = xml.xpath("/builddepinfo/package[@name]")
  cycles = xml.xpath("/builddepinfo/cycle")
  
  $stderr.puts "#{packages.count} packages, #{cycles.count} cycles"
  
  case format
  when "dot"
    require "dot"
    to_dot obs, packages, cycles
  when "tlp"
    require "tlp"
    to_tlp obs, packages, cycles
  else
    $stderr.puts "No output format given"
    usage
  end
rescue RuntimeError => e
  $stderr.puts e
  exit 1
end
