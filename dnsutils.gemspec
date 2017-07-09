# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dnsutils/version'

Gem::Specification.new do |spec|
  spec.name          = "dnsutils"
  spec.version       = Dnsutils::VERSION
  spec.authors       = ["iagox86"]
  spec.email         = ["ron-git@skullsecurity.org"]

  spec.summary       = "A set of DNS utilities that are useful for pentesters (or just general playing)."
  spec.homepage      = "https://github.com/iagox86/dnsutils"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest"

  spec.add_dependency "nesser"
  spec.add_dependency "trollop"
end
