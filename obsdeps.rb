#!/usr/bin/ruby
#
# == Synopsis
#
# obsdeps.rb - visualize _o_pensuse _b_uild _s_service _dep_endencie_s_
#
# == Usage
#
# obsdeps [-A <apiurl>] [-u <user>] [-p <password>] [-r <repo> ] [-a <arch> ] [-f format] <project>
#
# -r <repo>:
#   repository name, defaults to 'standard'
#
# -a <arch>:
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
# <project>:
#   project name
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
require File.join(File.dirname(__FILE__), 'buildservice')

  args = BuildService::DEFAULT_ARGS
  args << [ "--format",   "-f", GetoptLong::REQUIRED_ARGUMENT ]

  callback = lambda do |opt,arg|
    case opt
    when "--format": [:format, arg]
    else
      nil
    end
  end
  res = BuildService.scanargs args, callback
  RDoc::usage unless res

  format = res[:format]
  prjname = ARGV.shift

  project = begin
    BuildService::Project.new prjname, res
  rescue ArgumentError
    $stderr.puts "No project given"
    RDoc::usage
  rescue SecurityError
    $stderr.puts "Please provide username and password"
    RDoc::usage
  end

begin
  # verify existance of project

  exit 1 unless project.exists?

  # get buildepinfo

  xml = project.builddepinfo

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
    RDoc::usage
  end
rescue RuntimeError => e
  $stderr.puts e
  exit 1
end
