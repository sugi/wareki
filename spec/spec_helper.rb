#
require 'coveralls'
Coveralls.wear!

$:.unshift File.dirname(__FILE__)+'/../lib'
require 'simplecov'
require 'coveralls'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
]
SimpleCov.start do
  add_filter 'build-util/'
  add_filter 'spec/'
end

require 'wareki'
