require_relative "../test_helper"
require "linecounter"

class AnalyzerTest < Minitest::Test
  def setup
    @repo = Dir.mktmpdir("linecounter-analyzer")
    RepoBuilder.build(@repo)
  end

  def teardown
    FileUtils.remove_entry(@repo) if @repo && Dir.exist?(@repo)
  end

  def test_excludes_schema_rb
    refute_includes files, "db/schema.rb"
  end

  def test_rows_sorted_by_churn_then_branches_then_loc
    keys = analyze.rows.map { |r| [-r[:churn], -r[:branches], -r[:loc]] }
    assert_equal keys.sort, keys
  end

  def test_structure_overview_sums_per_file_type_counts
    result = analyze
    %i[public_methods association module_inclusion].each do |type|
      expected = result.rows.sum { |r| r[:structures][type] }
      assert_equal expected, result.structure_overview[type], "type=#{type}"
    end
  end

  def test_structure_item_counts_overview_sums_per_file_item_counts
    result = analyze
    %i[public_instance_method_def has_many].each do |key|
      expected = result.rows.sum { |r| r[:structure_item_counts][key] }
      assert_equal expected, result.structure_item_counts_overview[key], "key=#{key}"
    end
  end

  def test_min_loc_filters_small_files
    assert_operator analyze(min_loc: 1).rows.size, :>, 0
    assert_equal 0, analyze(min_loc: 1_000).rows.size
  end

  private

  def analyze(min_loc: 1)
    Linecounter::Analyzer.run(repo_path: @repo, min_loc: min_loc, since: nil)
  end

  def files
    analyze.rows.map { |r| r[:file] }
  end
end
