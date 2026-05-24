require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = false
end

task default: :test

# Never cut a release that doesn't pass the suite: `rake release` (build, tag
# v#{version}, push to RubyGems) runs the tests first and aborts on failure.
Rake::Task["release"].enhance(["test"])
