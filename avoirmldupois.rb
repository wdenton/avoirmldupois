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
require 'erb'
require 'haversine' # https://github.com/kristianmandrup/haversine
require 'ox' # https://github.com/ohler55/ox
require 'pg' # https://bitbucket.org/ged/ruby-pg/
require 'sinatra' # http://www.sinatrarb.com/
require 'sinatra/activerecord' # https://github.com/janko-m/sinatra-activerecord
require 'yaml'

# Note: use ActiveRecord as the object-relation mapper ...
# best thing going right now, it seems.
#
# Also, it means we can use sinatra/activerecord, which does
# some nice magic, like automatically loading and grokking
# config/database.yml, even on Heroku.

# Set up models for POIs, features, etc.
Dir.glob('./app/models/*.rb').each { |r| require r }

before do
  # Make this the default
  content_type 'application/json'
end

get "/:channel" do

  # The channel name has to be part of the URL.
  #
  # Mandatory params passed in as variables:
  # lat
  # lon
  # radius
  #
  # Optional:
  # format

  logger.debug "Requested channel #{params[:channel]}"

  begin
    channel = Channel.find_by name: params[:channel]

    # Just testing "if channel" threw all kinds of errors if the
    # channel didn't exist, so wrap this in a begin/rescue to catch
    # such errors. Must be a cleaner way to do this.

    logger.debug "Found channel #{channel.name}"

    latitude  = params[:lat].to_f
    longitude = params[:lon].to_f

    radius = params[:radius].to_i || 1000 # Default to 1000m radius if none provided

    logger.debug "Latitude: #{latitude}"
    logger.debug "Longitude: #{longitude}"
    logger.debug "Radius: #{radius}"

    logger.debug "Found #{channel.features.size} features"

    features = []

    channel.features.each do |f|

      # logger.debug Haversine.distance(f.latitude, f.longitude, latitude, longitude).to_meters

      # No distance calculation bulit in, so this will be slow.
      # TODO: Use spatial features of Postgres to do this inside the database.
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

  if params[:format] == "xml"

    content_type 'application/xml'

    # This is really ugly.  Why did I use Ox?
    # TODO: Use Nokogiri.
    doc = Ox::Document.new(:version => '1.0')
    xml_arml = Ox::Element.new('arml')
    doc << xml_arml
    xml_arelements = Ox::Element.new('arelements')
    xml_arml << xml_arelements
    features.each do |f|
      xml_feature = Ox::Element.new("feature")
      xml_feature[:id] = f["id"]
      xml_feature << (Ox::Element.new("name") << f['text']['name'])
      xml_feature << (Ox::Element.new("description") << f['text']['description'])
      x_anchors = Ox::Element.new("anchors")
      x_geometry = Ox::Element.new("geometry")
      x_gml = Ox::Element.new("gml:point")
      x_gml[:gml_id] = f["id"]
      x_gml << (Ox::Element.new("gml:pos") << "#{f['anchors']['geolocation']['lat']} #{f['anchors']['geolocation']['lon']}")
      x_geometry << x_gml
      x_anchors << x_geometry
      xml_feature << x_anchors
      xml_arelements << xml_feature
    end
    Ox.dump(doc)

  else # Good ol' JSON

    response = {
      "arml" => {
        "ARElements" => [
          features
        ]
      }
    }
    response.to_json

  end

  rescue # The requested channel is not known, so return an error

    errorstring = "Where do error messages go in ARML? No such channel is known."

    response = {
      "arml" => {
        "channel"   => params[:channel],
        "error"     => errorstring,
      }
    }

    logger.error errorstring
    response.to_json

  end

end

get "/*" do
  content_type "text/plain"
  "No known channel specified.  See https://github.com/wdenton/avoirmldupois"
end
