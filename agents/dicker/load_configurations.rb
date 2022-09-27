# -*- encoding : utf-8 -*-
require 'rubygems'
require 'logger'
require 'active_record'
require 'optparse'
require 'nokogiri'
require 'watir'
require 'mysql2'
require 'headless'
require 'net/ftp'
require 'simple_xlsx_reader'
require 'net/http'
require 'uri'
require 'json'
require 'roo'
require 'open-uri'


ActiveRecord::Base.default_timezone = :utc
require File.expand_path('../../lib/config/database_connection', __FILE__)
puts require File.expand_path('../../../config/application', __FILE__)
require File.expand_path('../../lib/models/dicker_detail', __FILE__)
require File.expand_path('../../lib/models/job_status', __FILE__)
#~ puts require File.expand_path('../../../config/boot', __FILE__)
#~ require File.expand_path('../../lib/config/*