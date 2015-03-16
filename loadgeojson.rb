#!/usr/bin/env ruby

require 'rubygems'

require 'active_record'
require 'open-uri'
require 'sinatra/activerecord' # https://github.com/janko-m/sinatra-activerecord
require 'uri'
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

  geo = {}
  channel_name = ""
  if /^http/.match(geojson_file)
    open(geojson_file) do |f|
      unless f.status[0] == '200'
        puts "Cannot open #{geojson_file}"
      else
        geo = JSON.parse(f.read)
      end
      channel_name = File.basename(URI.parse(geojson_file).path, ".geojson")
    end
  else
    geo = JSON.parse(File.read(geojson_file))
    channel_name = File.basename(geojson_file, ".geojson")
  end

  puts "Creating #{channel_name} ..."
  channel = Channel.find_or_create_by(name: channel_name)

  geo['features'].each do |f|
    puts f['properties']['Name']
    feature = Feature.create(
      :name             => f['properties']['Name'],
      :description      => f['properties']['description'],
      :latitude         => f['geometry']['coordinates'][1].to_f,
      :longitude        => f['geometry']['coordinates'][0].to_f,
    )
    channel.features << feature
  end

end
