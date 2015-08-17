#!/usr/bin/env ruby
#
# Usage: gen-jp-cal-def.rb kyuureki-map.txt > lib/calender_def.rb
#
require 'pp'
require 'date'

year = 0
month = 0
day = 0
leap = false
calinfo = Hash.new {|h, k| h[k] = {month_starts: [], month_days: []}}

ARGF.each do |line|
  line =~ /^(?<gy>[0-9]+)-(?<gm>[0-9]+)-(?<gd>[0-9]+)\s+(?<jy>[0-9]+)-(?<jm>[0-9]+)(?<jl>')?-(?<jd>[0-9]+)/ or next
  gdate = Date.new($~[:gy].to_i, $~[:gm].to_i, $~[:gd].to_i, Date::GREGORIAN)
  gdate.year == 1873 and break
  leap  = !!$~[:jl]
  year  = $~[:jy].to_i
  month = $~[:jm].to_i
  day   = $~[:jd].to_i
  cy = calinfo[year]
  cy[:end] = gdate.jd
  if day == 1
    month == 1 and
      cy[:start] = gdate.jd
    cy[:month_starts] << gdate.jd
    if leap
      cy[:leap] and raise "#{year} already has leap month (#{cy[:leap]} vs #{month})"
      cy[:leap] = month
    end
  end
  cy[:month_days][cy[:month_starts].count - 1] = gdate.jd - cy[:month_starts].last + 1
end

level = 3
puts "module Wareki"
puts "  Year = Struct.new(:year, :start, :end, :leap_month, :month_starts, :month_days)"
puts "  YEAR_DEFS = ["
calinfo.each do |year, d|
  puts "    Year.new(#{year}, #{d[:start]}, #{d[:end]}, #{d[:leap].inspect}, #{d[:month_starts].inspect}, #{d[:month_days].inspect}),"
end
puts "  ].freeze"
puts "end"
