# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
require "obs"

Gem::Specification.new do |s|
  s.name        = "obs"
  s.version     = Obs::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Klaus Kämpf"]
  s.email       = ["kkaempf@suse.de"]
  s.homepage    = "http://www.github.com/kkaempf/obs"
  s.summary = "Acces Open Build Service API"
  s.description = "OBS makes it easy to access the Open Build Service API"

  s.required_rubygems_version = ">= 1.3.6"
  s.add_development_dependency("yard", [">= 0.5"])
  s.add_dependency("nokogiri")
  s.add_dependency("net-netrc")
  s.add_dependency("inifile")

  s.files         = `git ls-files`.split("\n")
  s.files.reject! { |fn| fn == '.gitignore' }
  s.require_path = 'lib'
  s.extra_rdoc_files    = Dir['README.rdoc', 'CHANGES.rdoc', 'MIT-LICENSE']
  s.test_files    = `git ls-files -- test/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }

  s.post_install_message = <<-POST_INSTALL_MESSAGE
  ____
/@    ~-.
\/ __ .- | remember to have fun! 
 // //  @  

  POST_INSTALL_MESSAGE
end
