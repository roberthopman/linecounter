require_relative "test_helper"
require "json"

# Black-box golden master: runs the linecounter executable against a frozen
# fixture repo and compares stdout to a stored snapshot. Exercises the actual
# shipped binary (exe/linecounter via -Ilib). Regenerate snapshots
# intentionally with: UPDATE_GOLDEN=1 rake test
class CLIGoldenTest < Minitest::Test
  CASES = {
    "default"            => [],
    "min_loc_5"          => %w[--min-loc 5],
    "branch_count"       => %w[--show-branch-count],
    "structure_overview" => %w[--show-structure-overview],
    "detailed_structure" => %w[--detailed-structure],
    "no_churn"           => %w[--no-churn],
    "since"              => %w[--since 2023-05-15],
    "json"               => %w[--json --show-structure-overview --detailed-structure]
  }.freeze

  def setup
    @repo = Dir.mktmpdir("linecounter-fixture")
    RepoBuilder.build(@repo)
  end

  def teardown
    FileUtils.remove_entry(@repo) if @repo && Dir.exist?(@repo)
  end

  CASES.each do |name, extra|
    define_method(:"test_#{name}") { assert_golden(name, extra) }
  end

  def test_crud_only_controllers
    repo = Dir.mktmpdir("linecounter-controllers")
    build_controllers_repo(repo)
    output = normalize(run_cli(%W[--repo #{repo} --min-loc 1 --crud-only-controllers]))
    golden = File.join(GOLDEN_DIR, "crud_only_controllers.txt")

    if ENV["UPDATE_GOLDEN"]
      File.write(golden, output)
      skip "wrote golden: crud_only_controllers"
    else
      assert File.exist?(golden), "missing golden crud_only_controllers; run UPDATE_GOLDEN=1 rake test"
      assert_equal File.read(golden), output, "golden mismatch for crud_only_controllers"
    end
  ensure
    FileUtils.remove_entry(repo) if repo && Dir.exist?(repo)
  end

  def test_non_crud_controllers
    repo = Dir.mktmpdir("linecounter-controllers")
    build_controllers_repo(repo)
    output = normalize(run_cli(%W[--repo #{repo} --min-loc 1 --no-churn --non-crud-controllers]))
    golden = File.join(GOLDEN_DIR, "non_crud_controllers.txt")

    if ENV["UPDATE_GOLDEN"]
      File.write(golden, output)
      skip "wrote golden: non_crud_controllers"
    else
      assert File.exist?(golden), "missing golden non_crud_controllers; run UPDATE_GOLDEN=1 rake test"
      assert_equal File.read(golden), output, "golden mismatch for non_crud_controllers"
    end
  ensure
    FileUtils.remove_entry(repo) if repo && Dir.exist?(repo)
  end

  def test_crud_only_controllers_json
    repo = Dir.mktmpdir("linecounter-controllers")
    build_controllers_repo(repo)
    out = run_cli(%W[--repo #{repo} --min-loc 1 --crud-only-controllers --json])
    payload = JSON.parse(out)

    assert_equal [{ "file" => "app/controllers/posts_controller.rb",
                    "actions" => %w[index show create] }],
                 payload["crud_only_controllers"]
    refute payload["top"].any? { |r| r.key?("crud_profile") },
           "crud_profile should be stripped from JSON rows"
  ensure
    FileUtils.remove_entry(repo) if repo && Dir.exist?(repo)
  end

  def test_non_crud_controllers_json
    repo = Dir.mktmpdir("linecounter-controllers")
    build_controllers_repo(repo)
    out = run_cli(%W[--repo #{repo} --min-loc 1 --no-churn --non-crud-controllers --json])
    payload = JSON.parse(out)

    assert_equal [{ "file" => "app/controllers/comments_controller.rb",
                    "actions" => %w[index], "extra_actions" => %w[archive] }],
                 payload["non_crud_controllers"]
  ensure
    FileUtils.remove_entry(repo) if repo && Dir.exist?(repo)
  end

  def test_defaults_repo_to_current_directory
    out, _err, status = Open3.capture3(RUBY, "-I#{LIB}", EXE, chdir: @repo)
    assert status.success?, "expected success when --repo omitted inside a git repo"
    assert_equal File.read(File.join(GOLDEN_DIR, "default.txt")), normalize(out)
  end

  def test_aborts_when_current_directory_is_not_a_git_repo
    Dir.mktmpdir("linecounter-not-a-repo") do |dir|
      _out, err, status = Open3.capture3(RUBY, "-I#{LIB}", EXE, chdir: dir)
      refute status.success?
      assert_includes err, "Not inside a git repository"
    end
  end

  private

  def assert_golden(name, extra)
    output = normalize(run_cli(%W[--repo #{@repo}] + extra))
    golden = File.join(GOLDEN_DIR, "#{name}.txt")

    if ENV["UPDATE_GOLDEN"]
      FileUtils.mkdir_p(GOLDEN_DIR)
      File.write(golden, output)
      skip "wrote golden: #{name}"
    else
      assert File.exist?(golden), "missing golden #{name}; run UPDATE_GOLDEN=1 rake test"
      assert_equal File.read(golden), output, "golden mismatch for #{name}"
    end
  end

  def build_controllers_repo(dir)
    files = {
      "app/controllers/posts_controller.rb" => <<~RUBY,
        class PostsController < ApplicationController
          def index; end
          def show; end
          def create; end

          private

          def post_params; end
        end
      RUBY
      "app/controllers/comments_controller.rb" => <<~RUBY,
        class CommentsController < ApplicationController
          def index; end
          def archive; end
        end
      RUBY
      "app/models/post.rb" => <<~RUBY
        class Post
          def publish; end
        end
      RUBY
    }
    RepoBuilder.git(dir, "init", "-q", "-b", "main")
    files.each do |rel, content|
      dest = File.join(dir, rel)
      FileUtils.mkdir_p(File.dirname(dest))
      File.write(dest, content)
      RepoBuilder.git(dir, "add", rel)
    end
    RepoBuilder.git(dir, "commit", "-q", "-m", "init",
                    env: { "GIT_AUTHOR_DATE" => "2023-01-01T12:00:00",
                           "GIT_COMMITTER_DATE" => "2023-01-01T12:00:00" })
  end

  def run_cli(args)
    out, _err, _status = Open3.capture3(RUBY, "-I#{LIB}", EXE, *args)
    out
  end

  # Strip the only nondeterministic field in the output.
  def normalize(text)
    text.gsub(/"generated_at": "[^"]*"/, '"generated_at": "<TS>"')
  end
end
