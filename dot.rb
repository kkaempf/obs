# output builddepinfo as .dot for Graphviz
#
def to_dot obs, packages, cycles
  puts "digraph \"#{obs.project}\" {"
  packages.each do |node|
    name = node['name']
#    puts "# #{node.class}"
    node.xpath("./pkgdep").each do |child|
      puts "\"#{name}\" -> \"#{child.text.split(' ').first}\";"
    end
  end
    
  puts "overlap=false"
  puts "label=\"Build dependencies of #{obs.project} #{obs.repo} #{obs.arch}\""
  puts "fontsize=12;"
  puts "}"
end