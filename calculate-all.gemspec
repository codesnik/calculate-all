# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'calculate-all/version'

Gem::Specification.new do |spec|
  spec.name          = "calculate-all"
  spec.version       = CalculateAll::VERSION
  spec.authors       = ["Alexey Trofimenko"]
  spec.email         = ["aronaxis@gmail.com"]

  spec.summary       = %q{Fetch from database results of several aggregate functions at once}
  spec.description   = %q{Extends Active Record with #calculate_all method}
  spec.homepage      = "http://github.com/codesnik/calculate-all"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "pg"
  spec.add_development_dependency "mysql2"
  spec.add_development_dependency "groupdate"
end
