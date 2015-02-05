# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rubot/version'

Gem::Specification.new do |spec|
  spec.name          = "rubot"
  spec.version       = Rubot::VERSION
  spec.authors       = ["chrislee35"]
  spec.email         = ["rubygems@chrislee.dhs.org"]
  spec.description   = %q{Rubot gives the base classes to emulate (at a network level) a wide variety of botnet-like behaviors.}
  spec.summary       = %q{Rubot Botnet Emulation Framework}
  spec.homepage      = "http://github.com/chrislee35/rubot"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "eventmachine", ">= 0.12.10"
  spec.add_runtime_dependency "em-socksify", ">= 0.2.1"
  spec.add_runtime_dependency "sqlite3", ">= 1.3.6"
  spec.add_runtime_dependency "igrigorik-em-http-request", ">= 0.1.8"
  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"

  spec.signing_key   = "#{File.dirname(__FILE__)}/../gem-private_key.pem"
  spec.cert_chain    = ["#{File.dirname(__FILE__)}/../gem-public_cert.pem"]
end
