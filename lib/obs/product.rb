#
# product.rb
#
# A collection of classes to access openSUSE build service
#
# See http://api.opensuse.org
#

module Obs

class Product
  
  attr_reader :api, :uri, :user, :password, :name, :origin
  
  #
  # Obs::Project.new project (String), options (Hash) 
  #
  # Work with products defined in project (typically 'SUSE')
  #
  # option keys:
  #  - :api
  #  - :user
  #  - :password
  #
  def initialize(origin, name, options = nil)
    raise ArgumentError.new("Origin project missing") unless origin
    raise ArgumentError.new("Product name missing") unless name

    @api = Obs::Api.new(options)
    @origin = origin
    @name = name

  end
  
  def to_s
    "#{origin}:#{@name}"
  end

  #
  # get list of all products
  #
  # set options[:verbose] for more details
  #
  def self.all project, options = {}
    api = Obs::Api.new(options)
    view = (options[:verbose]) ? "verboseproductlist" : "productlist"
    api.get "/source/#{project}?view=#{view}&expand=1"
  end

  def exists?
    # check access to OBS

    begin
      resp = @api.get "/"
    rescue Exception => e
      $stderr.puts "Could not access obs server at #{@uri}: #{e}"
      return false
    end
    # verify existance of project

    true
  end

  # retrieve product definition
  def definition
    Obs::Definition.new(self)    
  end

end # class Product

end #Module Obs
