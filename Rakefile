# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'rake/hooks'
require 'fileutils'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new(:lint)

before :build do
  spec = Bundler.load_gemspec(File.join(File.dirname(__FILE__), 'wareki.gemspec'))
  FileUtils.chmod(0o644, spec.files)
end

task default: ENV['CI'] ? :spec : %i(spec lint)
