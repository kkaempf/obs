#
# package.rb
#
# A collection of classes to access openSUSE build service
#
# See http://api.opensuse.org
#

require 'getoptlong'

module Obs

class Package
  
  attr_reader :project, :name
  def initialize project = nil, name = nil
    unless project
      project = File.read(".osc/_project").chomp rescue nil
      raise ArgumentError.new unless project
      project = BuildService::Project.new project
    end
    @project = project
    unless name
      name = File.read(".osc/_package").chomp rescue nil
      raise ArgumentError.new unless package
    end
    @name = name
  end

  def to_s
    @name
  end
  
  def buildinfo
    # GET /build/<project>/<repository>/<arch>/<package>/_buildinfo
    @project.api :get, "/build/#{@project.name}/#{@project.repo}/#{@project.arch}/#{@name}/_buildinfo"
  end

  # enumerate source files of package
  def files
    # GET /source/<project>/<package>
    xml = @project.api :get, "/source/#{@project.name}/#{@name}"
    xml.xpath("/directory/entry/@name").each do |name|
      yield
    end
  end

  def file filename
    # GET /source/<project>/<package>/<filename>
    @project.api :get, "/source/#{@project.name}/#{@name}/#{filename}"
  end

  def builddepinfo
    # GET /build/<project>/<repository>/<arch>/_builddepinfo?package="package_name"
    @project.builddepinfo @name
  end
  
end # class Package

end #Module Obs
