# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "pej-rpc/version"

Gem::Specification.new do |s|
  s.name        = "pej-rpc"
  s.version     = Pej::Rpc::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Roy Ratcliffe"]
  s.email       = ["roy@pioneeringsoftware.co.uk"]
  s.homepage    = ""
  s.summary     = %q{Privacy Enhanced JSON-RPC}
  s.description = %q{Applies PEM encrypted privacy enhancement to JSON-RPC, a simple remote procedure-call protocol built on simple JSON encoding}

  s.rubyforge_project = "pej-rpc"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
