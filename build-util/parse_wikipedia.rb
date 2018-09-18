#!/usr/bin/ruby
# coding: utf-8

require 'open-uri'
require 'nokogiri'
require 'date'
require 'pp'

require File.dirname(__FILE__) + '/../lib/wareki/calendar_def'

module Wareki; end
class Wareki::Generator
  TARGET_URL = ARGV.first || 'https://ja.wikipedia.org/wiki/%E5%85%83%E5%8F%B7%E4%B8%80%E8%A6%A7_%28%E6%97%A5%E6%9C%AC%29'
  INF_DATE = Date.new(2**(0.size * 8 - 2) - 1, 12, 31) # Use max Fixnum as year.

  def generate(filename)
    open(filename, 'w') do |f|
      f.puts "# coding: utf-8"
      f.puts "module Wareki"
      f.puts "  Era = Struct.new(:name, :year, :start, :end)"
      f.puts dump_era
      f.puts "end"
    end
  end

  def dump_era(indent = '  ')
    ret = []
    (era_n, era_s) = get_data
    imperial_base = Date.new(-660, 2, 11, Date::GREGORIAN)
    {ERA_DEFS: era_s, ERA_NORTH_DEFS: era_n}.each do |label, vals|
      ret << "#{label} = ["
      vals.each do |g, d|
        year = nil
        if d[:start].new_start(Date::GREGORIAN).year >= 1873
          year = Date.new(d[:start].year, 1, 1, Date::GREGORIAN).year
        else
          year = Wareki::YEAR_DEFS.bsearch { |y| y.end > d[:start].jd }.year
        end
        ret << %Q{#{indent}Era.new("#{g}", #{year}, #{d[:start].jd}, #{d[:end].jd}),}
      end
      ret << "].freeze"
    end
    indent + ret.join("\n#{indent}")
  end

  def get_data
    era_n = {}
    era_s = {}
    cur_o = nil

    doc = Nokogiri::HTML open(TARGET_URL)

    doc.css('#content table.wikitable').each do |table|
      table.css('tr:nth-child(1) th:nth-child(1)').text.strip == "元号名" or next

      table.css('tr').each_with_index do |tr, tr_idx|
        tr_idx < 2 and next
        tr.css('th').empty? and next
        cols = tr.css('th, td').map { |n| n.text.strip }
        cols[0] == '－' || cols[0].empty? and next
        if era_n[cols[0]] || era_s[cols[0]]
          warn "WARN Overwrite: #{cols[0]}"
        end

        unless cols[2] =~ %r{\n.*[(（](?<year>\d+)年(?<month>\d+)月(?:(?<day>\d+)日)?[）)]|[(（](?<year>\d+)年[）)]\n(?<month>\d+)月(?<day>\d+)日}
          warn "Can't detect start date; #{cols.inspect}"
          next
        end
        start_date = Date.new($~[:year].to_i, ($~[:month] || 1).to_i, ($~[:day] || 1).to_i)

        end_date = nil
        if cols[3] =~ /[(（]継続[)）]/
          end_date = INF_DATE
        elsif cols[0] == '建武'
          if cols[3] =~ %r{[(（](?<syear>\d+)年(?<smonth>\d+)月(?<sday>\d+)日[）)].*[(（](?<nyear>\d+)年(?<nmonth>\d+)月(?<nday>\d+)日[）)]}m
            end_date = [Date.new($~[:syear].to_i, $~[:smonth].to_i, $~[:sday].to_i), Date.new($~[:nyear].to_i, $~[:nmonth].to_i, $~[:nday].to_i)]
          else
            raise
          end
        elsif cols[3] =~ %r{\n.*[(（](?<year>\d+)年(?<month>\d+)月(?:(?<day>\d+)日)?[）)]|[(（](?<year>\d+)年[）)]\n(?<month>\d+)月(?<day>\d+)日}
          end_date = Date.new($~[:year].to_i, ($~[:month] || 1).to_i, ($~[:day] || 1).to_i)
        else
          warn "Can't detect end date: #{cols.inspect}"
        end
        if end_date.kind_of?(Array)
          era_n[cols[0]] = {start: start_date, end: end_date.last}
          era_s[cols[0]] = {start: start_date, end: end_date.first}
        elsif cur_o == :n
          era_n[cols[0]] = {start: start_date, end: end_date}
        elsif cur_o == :s
          era_s[cols[0]] = {start: start_date, end: end_date}
        else
          era_s[cols[0]] = era_n[cols[0]] = {start: start_date, end: end_date}
        end
      end
    end
    [era_n, era_s]
  end
end

if $0 == __FILE__
  Wareki::Generator.new.generate(File.dirname(__FILE__) + '/../lib/wareki/era_def.rb')
end
