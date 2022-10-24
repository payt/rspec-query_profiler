# frozen_string_literal: true

# The namespace for this gem.
module RSpec
  module QueryProfiler
    VERSION = "0.3.0"
    PROFILE_LEVEL = ENV["PROFILE"].to_i
    IGNORED_QUERIES = ["TRANSACTION", "SCHEMA"].freeze
  end
end

require "rspec/core"
require "rspec/query_profiler/example"
require "rspec/query_profiler/memoized_helpers"
