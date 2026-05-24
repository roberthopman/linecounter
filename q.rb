#!/usr/bin/env ruby
# q.rb
# Lists Ruby files with lines of code, churn, branching, and avg loc per item.

require_relative "lib/linecounter"

Linecounter::CLI.run(ARGV)
