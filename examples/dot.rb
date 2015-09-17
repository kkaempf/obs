# output builddepinfo as .dot for Graphviz
#
def to_dot obs, packages, cycles
  puts "digraph \"#{obs.project}\" {"
  nhash = {}
  packages.each do |node|
    nhash[node['name']] = node
  end
  nhash.each do |name, node|
#    puts "# #{node.class}"
    node.xpath("./pkgdep").each do |child|
      cname = child.text.split(' ').first
      next unless nhash[cname]
      puts "\"#{name}\" -> \"#{cname}\";"
    end
  end

  puts "overlap=false"
  puts "label=\"Build dependencies of #{obs.project} #{obs.repo} #{obs.arch}\""
  puts "fontsize=12;"
  puts "}"
end