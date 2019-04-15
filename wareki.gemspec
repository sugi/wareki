lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'wareki/version'

Gem::Specification.new do |spec|
  spec.name          = 'wareki'
  spec.version       = Wareki::VERSION
  spec.authors       = ['Tatsuki Sugiura']
  spec.email         = ['sugi@nemui.org']

  spec.summary       = 'Pure ruby library of Wareki (Japanese calendar date)'
  spec.description   = <<-DESC
Pure ruby library of Wareki (Japanese calendar date) that supports string parsing,
formatting, and bi-directional convertion with standard Date class.
  DESC
  spec.homepage      = 'https://github.com/sugi/wareki'
  spec.license       = 'BSD'

  spec.files         = Dir['lib/**/*.rb'] + %w(LICENSE README.md ChangeLog)
  # spec.bindir        = "exe"
  # spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'ya_kansuji', '> 0.0.9', '< 2.0.0'

  spec.required_ruby_version = '>= 2.0.0'
  if RUBY_VERSION >= '2.1.0' && !defined?(JRUBY_VERSION)
    spec.add_development_dependency 'bundler', '>= 1.9'
  else
    spec.add_development_dependency 'bundler'
  end
  spec.add_development_dependency 'rake', '>= 10.0'
  spec.add_development_dependency 'rspec'
end
