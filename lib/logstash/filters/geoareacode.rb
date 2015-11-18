# encoding: utf-8
require "logstash/filters/base"
require "logstash/namespace"
require 'csv'

class LogStash::Filters::GeoAreaCode < LogStash::Filters::Base


  # filter {
  #   geoareacode { ... }
  # }
  config_name "geoareacode"

  # New plugins should start life at milestone 1.
  milestone 1
  
  # the location of the location file which pairs area code to latitude and longitude geo locations 
  config :database, :validate => :path

  # the field from which we get the location's area code
  config :source, :validate => :string, :required => true

  # the field in which we put the derived location
  config :target, :validate => :string, :default => 'location'

  config :locs 

  public
  def encode(value)
        if (value != nil && value.is_a?(String))
          # Some strings don't have the correct encoding...
          value = case value.encoding
                    when Encoding::ASCII_8BIT; value.force_encoding(Encoding::ISO_8859_1).encode(Encoding::UTF_8)
                    when Encoding::ISO_8859_1, Encoding::US_ASCII;  value.encode(Encoding::UTF_8)
                    else; value.dup
                  end
        end
  end #def encode

  public
  def register
    if @database.nil?
      @database = LogStash::Environment.vendor_path("/opt/db/GeoIPCity-534-Location.csv")
      if !File.exists?(@database)
        raise "You must specify 'database => ...' in your geoareacode filter (I looked for '#{@database}'"
      end
    end
    @logger.info("Using geo database: ", :path => @database)
    
    @locs = Hash.new
    CSV.foreach(@database) do |row|
      areaCode = encode(row[8])
      unless areaCode.nil?
        @logger.debug("Area Code: ", :areaCode => areaCode)
        latitude = encode(row[5]).to_f
        longitude = encode(row[6]).to_f

        #locId,country,region,city,postalCode,latitude,longitude,metroCode,areaCode
        @locs[areaCode] = [ longitude, latitude ] # { "lat" => row[5].to_f, "lon" => row[6].to_f }
      end
    end
    @logger.info("Ended up loading Geo DB")
  end # def register
  

  public
  def filter(event)
    # return nothing unless there's an actual filter event
    return unless filter?(event)

    if event[@source]
      areaCode = event[@source]
      if @locs[areaCode]
        @logger.debug("Found location for area code", {:areaCode => areaCode, :value => @locs[areaCode] })
        event[@target] = @locs[areaCode]
      else
        @logger.warn("Unmapped area code: ", {"areaCode" => areaCode})
      end
    end
    # filter_matched should go in the last line of our successful code 
    filter_matched(event)
  end # def filter
end # class LogStash::Filters::Foo