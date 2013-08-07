# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'reactor/version'

Gem::Specification.new do |spec|
  spec.name          = "reactor"
  spec.version       = Reactor::VERSION
  spec.authors       = ["winfred", "walt", "nate", "cgag", "petermin"]
  spec.email         = ["winfred@developerauction.com", "walt@developerauction.com", "curtis@developerauction.com", "nate@developerauction.com", "kengteh.min@gmail.com"]
  spec.description   = %q{ rails chrono reactor }
  spec.summary       = %q{ Sidekiq/ActiveRecord pubsub lib }
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "sidekiq", ">= 2.13.0"
  spec.add_dependency 'activerecord', '3.2.13'
  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
end
