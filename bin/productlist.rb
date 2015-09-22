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
as_xml = nil

loop do
  break if ARGV.empty?
  arg = ARGV.shift
  case arg
  when "-v"
    verbose = true
  when "-x"
    as_xml = true
  when "-n"
    name = ARGV.shift
  when "-a"
    api = ARGV.shift
  else
    usage "Unknown option '#{arg}'"
  end
end

# non-verbose
#   <product name="SUSE-Manager-Server" cpe="cpe:/o:suse:suse-manager-server:2.1" originproject="SUSE:SLE-11-SP3:Update:Products:Test:Update" mtime="1436182970"/>

# verbose
# <product name="SUSE-Manager-Server" originproject="SUSE:SLE-11-SP3:Update:Products:Test:Update">
#  <cpe>cpe:/o:suse:suse-manager-server:2.1</cpe>
#  <version>2.1</version>
#  <patchlevel>0</patchlevel>
# </product>
      
xml = Obs::Product.all project, :api => api, :verbose => verbose

unless name
  puts xml
else
  matches = xml.xpath(".//product[@name='#{name}']")
  usage "Can't find product #{name}" unless matches
  matches.each do |prodxml|
    origin = prodxml['originproject']
    product = Obs::Product.new origin, name, :api => api
    if as_xml
      puts product.definition.to_xml
    else
      puts product.definition
    end
  end
end
