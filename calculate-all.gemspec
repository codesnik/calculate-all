lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "calculate-all/version"

Gem::Specification.new do |spec|
  spec.name = "calculate-all"
  spec.version = CalculateAll::VERSION
  spec.authors = ["Alexey Trofimenko"]
  spec.email = ["aronaxis@gmail.com"]

  spec.summary = "Fetch from database results of several aggregate functions at once"
  spec.description = "Extends Active Record with #calculate_all method"
  spec.homepage = "http://github.com/codesnik/calculate-all"
  spec.license = "MIT"

  spec.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 2.4.0'

  spec.add_dependency "activesupport", ">= 4.0.0"
end
