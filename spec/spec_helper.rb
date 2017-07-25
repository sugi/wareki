#
$:.unshift File.dirname(__FILE__)+'/../lib'

unless defined? JRUBY_VERSION
  require 'coveralls'
  Coveralls.wear!

  require 'simplecov'
  require 'coveralls'

  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    Coveralls::SimpleCov::Formatter
  ])
  SimpleCov.start do
    add_filter 'build-util/'
    add_filter 'spec/'
  end
end

require 'wareki'
