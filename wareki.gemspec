lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'wareki/version'

Gem::Specification.new do |spec|
  spec.name          = "wareki"
  spec.version       = Wareki::VERSION
  spec.authors       = ["Tatsuki Sugiura"]
  spec.email         = ["sugi@nemui.org"]

  spec.summary       = %q{Pure ruby library of Wareki (Japanese calendar date)}
  spec.description   = %q{Wareki supports string parsing, formatting, and bi-directional convertion with standard Date class.}
  spec.homepage      = "https://github.com/sugi/wareki"
  spec.license       = "BSD"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features|build-util)/}) }
  #spec.bindir        = "exe"
  #spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.9"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
end

