# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("lib", __dir__)
require "rspec/query_profiler"

Gem::Specification.new do |spec|
  spec.name          = "rspec-query_profiler"
  spec.version       = RSpec::QueryProfiler::VERSION
  spec.authors       = ["Payt devs"]
  spec.email         = ["devs@paytsoftware.com"]

  spec.summary       = "Records executed queries during RSpec run"
  spec.homepage      = "https://www.paytsoftware.com"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.6"

  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  # spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^spec/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "activesupport"
  spec.add_runtime_dependency "rspec-core", "~> 3.10"

  spec.add_development_dependency "pry"
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "rubocop-performance"
  spec.add_development_dependency "rubocop-rspec"
end
