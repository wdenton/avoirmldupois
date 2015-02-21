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

require 'active_record'
require 'bundler/setup'
require 'haversine'
require 'ox'
require 'sinatra'
require 'sqlite3'
require 'yaml'

dbconfig = YAML::load(File.open('config/database.yml'))[ENV['RACK_ENV'] ? ENV['RACK_ENV'] : 'development']
ActiveRecord::Base.establish_connection(dbconfig)

Dir.glob('./app/models/*.rb').each { |r| require r }

before do
  # Make this the default
  content_type 'application/json'
end

get "/:channel" do

  # Mandatory params passed in:
  # channel
  # lat
  # lon
  # radius
  # format

  STDERR.puts params
  puts "Hello"

  channel = Channel.find_by name: params[:channel]

  if channel

    logger.debug "Found channel #{channel.name}"
    logger.debug channel

    latitude  = params[:lat].to_f
    longitude = params[:lon].to_f

    radius = params[:radius].to_i || 1000 # Default to 1000m radius if none provided

    logger.debug "Latitude: #{latitude}"
    logger.debug "Longitude: #{longitude}"
    logger.debug "Radius: #{radius}"

    # No distance calculation bulit in, so this will be slow.

    logger.debug "Found #{channel.features.size} features"

    features = []

    channel.features.each do |f|

      # logger.debug Haversine.distance(f.latitude, f.longitude, latitude, longitude).to_meters

      next if Haversine.distance(f.latitude, f.longitude, latitude, longitude).to_meters > radius

      feature = Hash.new
      feature["id"] = f.id
      feature["text"] = {
        "name"       => f.name,
        "description" => f.description,
      }
      feature["anchors"]  = {"geolocation" => {"lat" => f.latitude, "lon" => f.longitude}}

      logger.debug "Feature #{f.id}: #{f.name}"

      features << feature

    end

    if features.length == 0
      errorstring = "No results found.  Try adjusting your search range and any filters."
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

  if params[:format] == "xml"
    content_type 'application/xml'
    doc = Ox::Document.new(:version => '1.0')
    xml_arml = Ox::Element.new('arml')
    doc << xml_arml
    xml_arelements = Ox::Element.new('arelements')
    xml_arml << xml_arelements
    Ox.dump(doc)
  else
    response.to_json
  end

end

get "/*" do
  content_type "text/plain"
  "No parameters specified.  See https://github.com/wdenton/avoirmldupois"
end
