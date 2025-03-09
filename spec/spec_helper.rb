$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../lib"

unless defined? JRUBY_VERSION
  require 'simplecov'
  require 'coveralls'
  require 'simplecov-lcov'

  SimpleCov::Formatter::LcovFormatter.config do |c|
    c.report_with_single_file = true
    c.single_report_path = 'coverage/lcov.info'
  end
  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
                                                                   SimpleCov::Formatter::HTMLFormatter,
                                                                   Coveralls::SimpleCov::Formatter,
                                                                   SimpleCov::Formatter::LcovFormatter
                                                                 ])
  SimpleCov.start do
    add_filter 'build-util/'
    add_filter 'spec/'
  end
end

require 'wareki'
