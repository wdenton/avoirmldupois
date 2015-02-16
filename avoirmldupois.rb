#!/usr/bin/env ruby

# This file is part of AvoiRMLdupois.
#
# AvoiRMLdupois is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# AvoiRMLdupois is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with AvoiRMLdupois.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright 2012, 2013, 2014, 2015 William Denton

require 'rubygems'
require 'bundler/setup'

require 'sinatra'
# require 'nokogiri'
# require 'open-uri'

# require 'data_mapper'

require 'active_record'
require 'mysql2'
require 'yaml'

dbconfig = YAML::load(File.open('config/database.yml'))[ENV['RACK_ENV'] ? ENV['RACK_ENV'] : 'development']
ActiveRecord::Base.establish_connection(dbconfig)

Dir.glob('./app/models/*.rb').each { |r| require r }

# URL being called looks like this:
#
# http://www.miskatonic.org/ar/york.php?
# lang=en
# & countryCode=CA
# & userId=6f85d06929d160a7c8a3cc1ab4b54b87db99f74b
# & lon=-79.503089
# & version=6.0
# & radius=1500
# & lat=43.7731464
# & layerName=yorkuniversitytoronto
# & accuracy=100

# Mandatory params passed in:
# userId
# layerName
# version
# lat
# lon
# countryCode
# lang
# action
#
# Optional but important (what if no radius is specified?)
# radius

before do
  # Make this the default
  content_type 'application/json'
end

get "/" do

  # Error handling.
  # Status 0 indicates success. Change to number in range 20-29 if there's a problem.
  errorcode = 0
  errorstring = "ok"

  # See https://www.layar.com/documentation/browser/api/getpois-request/
  # for documentation on the GetPOIs request that is being handled here.

  channel = Channel.find_by name: params[:channelName]

  if channel

    logger.debug "Found channel #{channel.name}"
    logger.debug channel
    logger.debug channel.elements

    latitude  = params[:lat].to_f
    longitude = params[:lon].to_f

    radius = params[:radius].to_i || 1000 # Default to 1000m radius if none provided

    logger.debug "Latitude: #{latitude}"
    logger.debug "Longitude: #{longitude}"
    logger.debug "Radius: #{radius}"

    # Find all of the ELEMENTs in range in this channel.
    #
    # There's a slightly ugly SQL statement here that's used with a
    # find_by_sql statement because we can't use the ActiveRecord methods
    # to do exactly what we want: determining the distances between the
    # user and the ELEMENTs.  We need to use the Haversine formula for this.
    # In the SQL statement we do a calculation (thanks to MySQL having all
    # of this built in) and then assign that number to the variable
    # distance, then select and sort based on distance.  It would be nice
    # if we could use ActiveRecord normally to do this, with some sort of
    # class method on Element, but we can't, because there's no way to get
    # "as" into the statement.
    #
    # If we didn't need to bother so much about distance, we could just do
    # a query like this:
    #
    # @channel.elements.group(:id).checkboxed(checkmarks).each do |element|
    #   next unless element.within_radius(latitude, longitude, radius)
    #   puts element.title
    # end
    #
    # That works fine.  See element.rb for the checkboxed method, with uses
    # ActiveRecord's join and where commands to control the SQL the way we
    # want.
    #
    # If there really is some way to say
    # @channel.elements.group(:id).within_range(latitude, longitude, radius)
    # then we definitely want to use it.

    # Note re tests: make sure the id numbers returned are unique.
    # Not specifying IDs from the elements table will lead to trouble.

    sql = "SELECT p.*,
 (((acos(sin((? * pi() / 180)) * sin((lat * pi() / 180)) +  cos((? * pi() / 180)) * cos((lat * pi() / 180)) * cos((? - lon) * pi() / 180))) * 180 / pi())* 60 * 1.1515 * 1.609344 * 1000) AS distance
 FROM  elements p
 WHERE p.channel_id = ?
 GROUP BY p.id
 HAVING distance < ?
 ORDER BY distance asc" # "
    elements = Element.find_by_sql([sql, latitude, latitude, longitude, channel.id, radius])

    logger.debug "Found #{elements.size} ELEMENTs"

    elements.each do |element|
      # TODO: Add paging through >50 results.
      # STDERR.puts element.title
      feature = Hash.new
      feature["id"] = element.id
      feature["text"] = {
        "name"       => element.name,
        "description" => element.description,
        "footnote"    => element.footnote
      }
      feature["anchors"]         = {"geolocation" => {"lat" => element.lat, "lon" => element.lon}}
      feature["imageURL"]       = element.imageURL
      feature["biwStyle"]       = element.biwStyle
      feature["showSmallBiw"]   = element.showSmallBiw
      feature["showBiwOnClick"] = element.showBiwOnClick

      logger.debug "Feature #{element.id}: #{element.title}"

      if element.actions
        feature["actions"] = []
        element.actions.each do |action|
          # STDERR.puts action["label"]
          feature["actions"] << {
            "uri"          => action.uri,
            "label"        => action.label,
            "contentType"  => action.contentType,
            "activityType" => action.activityType,
            "method"       => action.method
          }
        end
      end

      if element.icon
        feature["icon"] = {
          "url"  => element.icon.url,
          "type" => element.icon.iconType
        }
      end

    end

    features << feature
  end

  if features.length == 0
    errorcode = 21
    errorstring = "No results found.  Try adjusting your search range and any filters."
    # TODO Make error message customizable?
  end

  response = {
    "arml" => {
      "ARElements" => [
        # "channel"           => channel.name,
        # "showMessage"     => channel.showMessage, # + " (#{ENV['RACK_ENV']})",
        # "refreshDistance" => channel.refreshDistance,
        # "refreshInterval" => channel.refreshInterval,
        features
        # "errorCode"       => errorcode,
        # "errorString"     => errorstring,
      ]
    }
  }

else # The requested channel is not known, so return an error

  errorstring = "Where do error messages go?"

  response = {
    "arml" => {
      "channel"   => params[:channelName],
      "error"     => errorstring,
    }
  }

  logger.error errorstring

end

response.to_json

end

get "/*" do
  content_type "text/plain"
  "No parameters specified.  See https://github.com/wdenton/avoirmldupois"
end
