lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'wareki/version'

Gem::Specification.new do |spec|
  spec.name          = "wareki"
  spec.version       = Wareki::VERSION
  spec.authors       = ["Tatsuki Sugiura"]
  spec.email         = ["sugi@nemui.org"]

  spec.summary       = %q{Pure ruby library of Wareki (Japanese calendar date)}
  spec.description   = %q{Pure ruby library of Wareki (Japanese calendar date) that supports string parsing, formatting, and bi-directional convertion with standard Date class.}
  spec.homepage      = "https://github.com/sugi/wareki"
  spec.license       = "BSD"

  spec.files         = Dir['lib/**/*.rb'] + %w(LICENSE README.rdoc)
  #spec.bindir        = "exe"
  #spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.0.0"
  if RUBY_VERSION >= "2.1.0" && !defined?(JRUBY_VERSION)
    spec.add_development_dependency "bundler", "~> 1.9"
  else
    spec.add_development_dependency "bundler"
  end
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
end
