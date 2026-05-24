require "minitest/autorun"
require "open3"
require "tmpdir"
require "fileutils"
require "rbconfig"
require_relative "support/repo_builder"

ROOT = File.expand_path("..", __dir__)
Q_RB = File.join(ROOT, "q.rb")
GOLDEN_DIR = File.join(__dir__, "golden")
RUBY = RbConfig.ruby

$LOAD_PATH.unshift File.join(ROOT, "lib")
