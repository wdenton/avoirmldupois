#!/usr/bin/env ruby

# This file is part of Avoirdupois.
#
# Avoirdupois is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Avoirdupois is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Avoirdupois.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright 2012, 2013 William Denton

require 'rubygems'
require 'active_record'
require 'sqlite3'
require 'yaml'

this_directory = File.dirname(__FILE__)

dbconfig = YAML::load(File.open("#{this_directory}/config/database.yml"))[ENV['RACK_ENV'] ? ENV['RACK_ENV'] : 'development']
puts "Setting up database: #{dbconfig['database']}"

ActiveRecord::Base.establish_connection(dbconfig)

ActiveRecord::Schema.define(:version => 001) do

  if table_exists? "channels"
    drop_table "channels"
  end
  create_table "channels", :force => true do |t|
    t.string     :name, :null => false
  end

  if table_exists? "features"
    drop_table "features"
  end
  create_table "features", :force => true do |t|
    t.references :channel
    t.string     :name, :null => false
    t.string     :description
    t.float      :latitude,  :null => false
    t.float      :longitude, :null => false
  end

end
