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
# Copyright 2012, 2013, 2015 William Denton

require 'rubygems'
require 'active_record'
require 'mysql2'
require 'yaml'

this_directory = File.dirname(__FILE__)

dbconfig = YAML::load(File.open("#{this_directory}/config/database.yml"))[ENV['RACK_ENV'] ? ENV['RACK_ENV'] : 'development']
puts "Setting up database: #{dbconfig['database']}"

ActiveRecord::Base.establish_connection(dbconfig)

# Primary key columns named "id" will be created automatically,
# but with ActiveRecord there's no special way to specify a
# foreign key.

ActiveRecord::Schema.define(:version => 001) do
  if table_exists? "channels"
    drop_table "channels"
  end
  create_table "channels", :force => true do |t|
    t.string     :name, :null => false
    t.string     :showMessage
  end

  if table_exists? "elements"
    drop_table "elements"
  end
  create_table "elements", :force => true do |t|
    t.references :channel
    # t.references :action
    t.string     :name, :null => false
    t.string     :description
    t.string     :footnote
    t.float      :lat, :null=> false
    t.float      :lon, :null=> false
    t.string     :imageURL
    t.float      :alt, :default => 0
    t.string     :elementType, :null => false, :default => "geo"
  end

  if table_exists? "icons"
    drop_table "icons"
  end
  create_table "icons", :force => true do |t|
    t.references :element
    t.string     :label
    t.string     :url, :null => false
    t.integer    :iconType, :null => false, :default => 0
  end

  if table_exists? "actions"
    drop_table "actions"
  end
  create_table "actions", :force => true do |t|
    t.references :element
    t.string     :label, :null => false
    t.string     :uri, :null => false
    t.string     :contentType, :default => "application/vnd.layar.internal"
    t.string     :method, :default => "GET"   # "GET", "POST"
    t.integer    :activityType, :deault => 1
    t.string     :params
    t.boolean    :closeBiw, :default => false
    t.boolean    :showActivity, :default => false
    t.string     :activityMessage
    t.boolean    :autoTrigger, :required => true, :default => false
    t.integer    :autoTriggerRange
    t.boolean    :autoTriggerOnly, :default => false
  end

end
