# Builds a deterministic, fully isolated git repo from test/fixtures/sample.
#
# The commit history is scripted so that churn (commits-per-file) and --since
# results are identical on every machine and every run. Files carry a "# rev: N"
# marker; earlier revisions are produced by rewriting that number, so the file
# checked out at HEAD is byte-identical to the fixture on disk.
require "fileutils"
require "open3"

module RepoBuilder
  SAMPLE_DIR = File.expand_path("../fixtures/sample", __dir__)

  # [message, commit_date, { relative_path => rev_number_or_nil }]
  COMMITS = [
    ["init",               "2023-01-01T12:00:00", { "lib/util.rb" => nil, "db/schema.rb" => nil }],
    ["add widget",         "2023-02-01T12:00:00", { "app/models/widget.rb" => 1 }],
    ["add calc",           "2023-03-01T12:00:00", { "app/services/calc.rb" => 1 }],
    ["tweak widget",       "2023-04-01T12:00:00", { "app/models/widget.rb" => 2 }],
    ["tweak widget again", "2023-05-01T12:00:00", { "app/models/widget.rb" => 3 }],
    ["tweak calc",         "2023-06-01T12:00:00", { "app/services/calc.rb" => 2 }]
  ].freeze

  module_function

  def build(dir)
    git(dir, "init", "-q", "-b", "main")
    COMMITS.each do |message, date, files|
      files.each do |rel, rev|
        write_revision(dir, rel, rev)
        git(dir, "add", rel)
      end
      git(dir, "commit", "-q", "-m", message,
          env: { "GIT_AUTHOR_DATE" => date, "GIT_COMMITTER_DATE" => date })
    end
    dir
  end

  def write_revision(dir, rel, rev)
    content = File.read(File.join(SAMPLE_DIR, rel))
    content = content.gsub(/# rev: \d+/, "# rev: #{rev}") if rev
    dest = File.join(dir, rel)
    FileUtils.mkdir_p(File.dirname(dest))
    File.write(dest, content)
  end

  def git(dir, *args, env: {})
    base_env = {
      "GIT_CONFIG_GLOBAL" => File::NULL,
      "GIT_CONFIG_SYSTEM" => File::NULL,
      "GIT_AUTHOR_NAME" => "Test", "GIT_AUTHOR_EMAIL" => "test@example.com",
      "GIT_COMMITTER_NAME" => "Test", "GIT_COMMITTER_EMAIL" => "test@example.com"
    }
    out, err, status = Open3.capture3(base_env.merge(env), "git", "-C", dir, *args)
    raise "git #{args.join(' ')} failed: #{err}" unless status.success?

    out
  end
end
