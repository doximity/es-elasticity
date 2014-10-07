# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'elasticity/version'

Gem::Specification.new do |spec|
  spec.name          = "es-elasticity"
  spec.version       = Elasticity::VERSION
  spec.authors       = ["Rodrigo Kochenburger"]
  spec.email         = ["rodrigo@doximity.com"]
  spec.summary       = %q{ActiveModel-based library for working with ElasticSearch}
  spec.description   = %q{Elasticity provides a higher level abstraction on top of [elasticsearch-ruby](https://github.com/elasticsearch/elasticsearch-ruby) gem}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  # spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.executables   = []
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.1.0"
  spec.add_development_dependency "simplecov", "~> 0.7.1"
  spec.add_development_dependency "oj"
  spec.add_development_dependency "pry"

  spec.add_dependency "activesupport", "~> 4.0.0"
  spec.add_dependency "activemodel",   "~> 4.0.0"
  spec.add_dependency "elasticsearch", "~> 1.0.5"
end
