#!/usr/bin/ruby
#
# == Synopsis
#
# installable.rb - check if a project/package is installable
#
# == Usage
#
# buildable [-A <apiurl>] [-u <user>] [-p <password>] [ -r <repo> ] [ -a <arch> ] [ -e <extra_provides> ] <project> [ <package>]
#
# <project>:
#   project name
#
# -r <repo>:
#   repository name, defaults to 'standard'
#
# -a <arch>:
#   architecture, defaults to 'i586'
#
# -e <extra_provides>:
#   List of 'extra' provides (one per line) to be injected
#
# <package>:
#   package name
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
# Note:
# username and password are extracted either from ~/.oscrc
# or from ~/.netrc if the respective gems are installed.
# Support for ~/.oscrc requires rubygem-ini, support for ~/.netrc
# requires rubygem-net-netrc
#
#

require 'rubygems'
require 'getoptlong'
require 'rdoc/usage'
require File.join(File.dirname(__FILE__), 'buildservice')
require 'satsolver'
require 'tempfile'

def create_project prjname, options
#  puts "create_project #{prjname}"
  begin
    BuildService::Project.new prjname, options
  rescue ArgumentError
    $stderr.puts "No project given"
    RDoc::usage
  rescue SecurityError
    $stderr.puts "Please provide proper username and password"
    RDoc::usage
  end
end

def expand_meta prjname, options
#  puts "expand meta #{prjname}"
  project = create_project prjname, options
  raise if project.nil?
  projects = [ project ]

  puts "  for #{project.name} : #{project.repo}"

  meta = project.meta
#  puts "meta #{meta}"
  subprojects = []
  meta.xpath("/project/repository[@name=\"#{project.repo}\"]/path").each do |path|
#    puts "repo #{path}"
    subprojects << [ path.xpath("@project").to_s, path.xpath("@repository").to_s ]
  end
  until subprojects.empty?
    prjname, repo = subprojects.shift
    options.merge! :repo => repo
    if subprojects.empty? # last project gets expanded
      projects.concat(expand_meta prjname, options)
    else
      projects << create_project(prjname, options)
    end
  end
  projects
end


  args = BuildService::DEFAULT_ARGS
  args << [ "--extra_provides",   "-e", GetoptLong::REQUIRED_ARGUMENT ]
  callback = lambda do |opt,arg|
    case opt
    when "--extra_provides": [:extra_provides, arg]
    else
      nil
    end
  end
  
  options = BuildService.scanargs args, callback
  RDoc::usage unless options

  prjname = ARGV.shift
  package = ARGV.shift

  # Start with the given project
  #  get its _meta information
  #  add each repo in the _meta to the project list
  #  recursively expand the last repo in the _meta
  
  puts "Fetching meta information for #{prjname} with #{options}"
  projects = expand_meta prjname, options

begin
  
  puts "Fetching solv files"

  pool = Satsolver::Pool.new
  main = nil
  
  projects.each do |project|
    # verify existance of project

    exit 1 unless project.exists?

    puts "  for #{project.name} : #{project.repo}"
    solv = project.solv

    temp = Tempfile.new "solv"
    temp.syswrite solv
    temp.close
  
    repo = pool.add_solv temp.path
#  puts "> Project #{project.name.class} : #{project.repo}"
    repo.name = project.name
    unless main
      main = repo
      pool.arch = project.arch
    end
  end

  repo = pool.create_repo("extra_provides")
  extra_provides = repo.create_solvable("extra_provides", "1.0-0", "noarch")

  if options[:extra_provides]
    File.open(options[:extra_provides]) do |f|
      while line = f.gets
	extra_provides.provides << pool.create_relation( line.chomp )
      end
    end
  end

  again = false
  
  loop do
    pool.prepare
    request = Satsolver::Request.new( pool )
  
    if package
      puts "Installing package #{package}"
      request.install( package )
    elsif main
      puts "Installing repo #{main.name}"
      main.each do |s|
	request.install( s.name )
      end
    else
      raise "Nothing to install ?!"
    end
  
    puts "Solving"
    solver = Satsolver::Solver.new( pool )
    res = solver.solve( request )
    if res
      puts "Success !"
      break
    end
    $stderr.puts "Not installable" 
    
    i = 0
    solver.each_problem( request ) do |p|
      i += 1
      j = 0
      p.each_ruleinfo do |ri|
	next if ri.command == Satsolver::SOLVER_RULE_JOB
	j += 1
	puts "  #{i}.#{j}: #{ri}"
	if ri.command == Satsolver::SOLVER_RULE_RPM_NOTHING_PROVIDES_DEP
	  extra_provides.provides << ri.relation
	  again = true
	end
      end
    end
    next if again
    puts "Failed"
    break
  end

  if again
    extra_provides.provides.each { |p| puts "#{p}" }
  end

rescue RuntimeError => e
  $stderr.puts e
  exit 1
end
