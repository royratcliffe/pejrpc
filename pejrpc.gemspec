# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "pejrpc/version"

Gem::Specification.new do |s|
  s.name        = "pejrpc"
  s.version     = PejRPC::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Roy Ratcliffe"]
  s.email       = ["roy@pioneeringsoftware.co.uk"]
  s.homepage    = ""
  s.summary     = %q{Privacy Enhanced JSON-RPC}
  s.description = %q{Applies PEM encrypted privacy enhancement to JSON-RPC, a simple remote procedure-call protocol built on simple JSON encoding}

  s.rubyforge_project = "pejrpc"

  s.add_runtime_dependency 'addressable'
  s.add_runtime_dependency 'json'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
