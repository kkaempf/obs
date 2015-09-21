#
# get list of products defined in project
#
# Usage: productlist.rb <project> [<api>]
#
$:.unshift File.expand_path(File.join(File.dirname(__FILE__), "..", "lib"))

def usage msg=nil
  STDERR.puts "Err: #{msg}" if msg
  STDERR.puts "productlist <project> [-v] [-a <api>]"

  exit (msg)?1:0
end

require 'obs'

project = ARGV.shift
usage "No project given" unless project

api = "https://api.suse.de"
verbose = nil
name = nil

loop do
  break if ARGV.empty?
  arg = ARGV.shift
  case arg
  when "-v"
    verbose = true
  when "-n"
    name = true
  when "-a"
    api = ARGV.shift
  else
    usage "Unknown option '#{arg}'"
  end
end

all = Obs::Product.all project, :api => api, :verbose => verbose

puts all
