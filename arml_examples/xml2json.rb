#!/usr/bin/env ruby

# Convert XML to JSON with the aptly named xml2json gem.

require 'rubygems'
require 'xml2json'

xmlfile = ARGV[0]

if xmlfile.nil?
  puts "No XML input file given"
  exit
end

puts XML2JSON.parse(File.read(xmlfile))
