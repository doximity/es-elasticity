# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "elasticity/version"

Gem::Specification.new do |spec|
  spec.name          = "es-elasticity"
  spec.version       = Elasticity::VERSION
  spec.authors       = ["Rodrigo Kochenburger"]
  spec.email         = ["rodrigo@doximity.com"]
  spec.summary       = %q{ActiveModel-based library for working with Elasticsearch}
  spec.description   = %q{Elasticity provides a higher level abstraction on top of [elasticsearch-ruby](https://github.com/elasticsearch/elasticsearch-ruby) gem}
  spec.homepage      = "https://github.com/doximity/es-elasticity"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
    spec.files = `git ls-files -z`.split("\x0").reject do |f|
      f.match(%r{^(bin|test|spec|vendor|tmp|coverage)/})
    end
  spec.executables   = []
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.5"
  spec.add_development_dependency "byebug"
  spec.add_development_dependency "codeclimate-test-reporter"
  spec.add_development_dependency "oj"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "redis"
  spec.add_development_dependency "rspec", "~> 3.13.0"
  spec.add_development_dependency "rspec_junit_formatter"
  spec.add_development_dependency "simplecov", "~> 0.22.0"
  spec.add_development_dependency "timecop"

  spec.add_dependency "activemodel",   ">= 5.2.0", "<= 7.2"
  spec.add_dependency "activerecord",   ">= 5.2.0", "<= 7.2"
  spec.add_dependency "activesupport", ">= 5.2.0", "<= 7.2"
  spec.add_dependency "elasticsearch", ">= 7", "< 8.7"
  spec.add_dependency "elastic-transport", ">= 8.0", "< 8.7"
end
