#
# get list of products defined in project
#
# Usage: productlist.rb <project> [<api>]
#
$:.unshift File.expand_path(File.join(File.dirname(__FILE__), "..", "lib"))

require 'obs'

project = ARGV.shift
raise "No project given" unless project

api = ARGV.shift || "https://api.suse.de"

product = Obs::Product.new project, :api => api
all = product.all

puts all
