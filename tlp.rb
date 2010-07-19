#
# tlp.rb
#
# Output buidldepinfo as .tlp format (for Tulip)
#

def to_tlp obs, packages, cycles
  channel = $stdout
  
  with_edgelabels = true
  channel.printf "(nodes"
		   
  nhash = {}

  num = 1
  packages.each do |node|
    nhash[node['name']] = num
    channel.printf " #{num}"
    num += 1
  end
  channel.puts ")"

  edges = []
  edgenum = 1
  packages.each do |node|
    name = node['name']
    channel.puts "# Node '#{name}'"
    from = nhash[name]
    node.xpath("./pkgdep").each do |child|
      cname = child.text.split(' ').first
      channel.puts "#  to  '#{cname}'"
      next unless nhash[cname]
      channel.puts "(edge #{edgenum} #{nhash[name]} #{nhash[cname]})"
      edgenum += 1
    end
  end
  
  channel.puts '(property 0 string "viewLabel"'
  channel.puts '  (default "" "")'
  packages.each do |node|
    name = node['name']
    channel.puts "  (node #{nhash[name]} \"#{name}\")"
  end
#  edges.each do |edge|
#    channel.puts "  (edge #{edge.num} \"#{edge.name}\")"
#  end
  channel.puts ")"

  channel.puts '(property 0 string "viewSize"'
  channel.puts '  (default "(0,0,0)" "(1,1,1)")'
  channel.puts ")"

  channel.puts '(property 0 color "viewColor"'
  channel.puts '  (default "(235,0,23,255)" "(0,0,0,0)")'
  channel.puts ")"

  channel.puts '(property 0 layout "viewLayout"'
  channel.puts '  (default "(0,0,0)" "()")'
  channel.puts ")"
end
