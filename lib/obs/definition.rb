#
# definition.rb
#
# A collection of classes to access openSUSE build service
#
# Here: Obs::Definition to express a <product>...</product> entry of a .product file
#
#
#<productdefinition>
#  <products>
#    <product>
#      <vendor>...
#      <name>...
#      <baseversion>...
#      <patchlevel>...
#      <summary>...
                
# See http://api.opensuse.org
#

module Obs

class Definition  

  # content of .product
  attr_reader :vendor, :name, :version, :patchlevel, :summary

  #
  # Obs::Definition.new product (Obs::Product)
  def initialize(product)
    @product = product # Obs::Product
    @xml = @product.api.get "/source/#{self.origin}/_product/#{self.productname}.product"
    case @xml
    when String
      @xml = Nokogiri::XML(@xml)
    end
    product = @xml.xpath("//products/product").first
    @vendor = product.xpath("vendor").text
    @name = product.xpath("name").text
    @version = product.xpath("version").text
    @patchlevel = product.xpath("patchlevel").text
    @summary = product.xpath("summary").text
  end
  def to_xml
    @xml
  end
  def to_s
    "#{@vendor};#{@name};#{@version};#{@patchlevel} : #{summary}"
  end

  # keys to access .product file
  # -> /source/#{origin}/_product/#{productname}.product
  def origin
    @product.origin
  end
  def productname
    @product.name
  end

end # class Product

end #Module Obs
