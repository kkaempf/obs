#
# product.rb
#
# A collection of classes to access openSUSE build service
#
# See http://api.opensuse.org
#

module Obs

class Product
  
  attr_reader :uri, :user, :password, :name
  
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
  def initialize(project = nil, options = nil)
    raise ArgumentError.new("Project missing") unless project

    @api = Obs::Api.new(options)
    @name = project

  end
  
  def to_s
    @name
  end

  #
  # get list of all products
  #
  # set options[:verbose] for more details
  #
  def self.all project, options = {}
    api = Obs::Api.new(options)
    view = options[:verbose] ? "verboseproductlist" : "productlist"
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

end # class Product

end #Module Obs
