#
# obs.rb
#
# A command line client to access Open Build Service API
#
# Copyright (c) 2015, SUSE Linux LLC
# Written by Klaus Kaempf <kkaempf@suse.de>
#
# Licensed under the MIT license
#
require 'rubygems'

module Obs
  VERSION = "0.1.0"
  require "obs/obs"
  require "obs/package"
  require "obs/project"
  require "obs/product"
  @@debug = nil
  def Obs.debug
    @@debug
  end
  def Obs.debug= level
    @@debug = (level == 0) ? nil : level
  end       
end # Module
