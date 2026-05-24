require_relative "test_helper"

# Black-box golden master: runs q.rb against a frozen fixture repo and compares
# stdout to a stored snapshot. Pins current behavior (including known bugs) so
# the upcoming refactor is provably behavior-preserving. Regenerate snapshots
# intentionally with: UPDATE_GOLDEN=1 rake test
class CLIGoldenTest < Minitest::Test
  CASES = {
    "default"            => [],
    "min_loc_5"          => %w[--min-loc 5],
    "branch_count"       => %w[--show-branch-count],
    "structure_overview" => %w[--show-structure-overview],
    "detailed_structure" => %w[--detailed-structure],
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

  def test_requires_repo
    out, _err, status = Open3.capture3(RUBY, Q_RB)
    assert_includes out, "--repo PATH is required"
    refute status.success?, "expected non-zero exit when --repo is omitted"
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

  def run_cli(args)
    out, _err, _status = Open3.capture3(RUBY, Q_RB, *args)
    out
  end

  # Strip the only nondeterministic field in the output.
  def normalize(text)
    text.gsub(/"generated_at": "[^"]*"/, '"generated_at": "<TS>"')
  end
end
