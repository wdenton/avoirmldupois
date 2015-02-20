#!/usr/bin/env ruby

require 'rubygems'

require 'active_record'
require 'bundler/setup'
require 'sinatra'
require 'sqlite3'
require 'yaml'

this_directory = File.dirname(__FILE__)
dbconfig = YAML::load(File.open("#{this_directory}/config/database.yml"))[ENV['RACK_ENV'] ? ENV['RACK_ENV'] : 'development']
ActiveRecord::Base.establish_connection(dbconfig)

Dir.glob('./app/models/*.rb').each { |r| require r }

geojson_files = ARGV

if geojson_files.nil?
  STDERR.puts "No GeoJSON file(s) specified"
  exit
end

geojson_files.each do |geojson_file|

  geo = JSON.parse(File.read(geojson_file))

  geo["features"].each do |f|
    name = f["properties"]["Name"]
    description = f["properties"]["description"]
    geometry_type = f["geometry"]["type"]
    (geometry_longitude, geometry_latitude) = f["geometry"]["coordinates"][0], f["geometry"]["coordinates"][1]

    STDERR.puts "(#{name}, #{description}, #{geometry_type}, #{geometry_latitude}, #{geometry_latitude}, #{geometry_longitude})"

    # db.execute "insert into features (name, description, geometry_type, geometry_latitude, geometry_longitude) values (?, ?, ?, ?, ?)", [name, description, geometry_type, geometry_latitude, geometry_longitude]

  end

end
