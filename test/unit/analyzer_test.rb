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

  def test_churn_false_skips_git_churn_and_zeroes_the_column
    widget = ->(rows) { rows.find { |r| r[:file] == "app/models/widget.rb" } }

    with_churn = Linecounter::Analyzer.run(repo_path: @repo, min_loc: 1, since: nil, churn: true)
    without_churn = Linecounter::Analyzer.run(repo_path: @repo, min_loc: 1, since: nil, churn: false)

    assert_operator widget.call(with_churn.rows)[:churn], :>, 0
    assert_equal 0, widget.call(without_churn.rows)[:churn]
    assert(without_churn.rows.all? { |r| r[:churn].zero? })
  end

  def test_attaches_crud_profile_only_to_controller_files
    repo = Dir.mktmpdir("linecounter-controllers")
    build_repo(repo,
      "app/controllers/posts_controller.rb" => <<~RUBY,
        class PostsController < ApplicationController
          def index; end
          def show; end
        end
      RUBY
      "app/models/post.rb" => <<~RUBY)
        class Post
          def index; end
        end
      RUBY

    rows = Linecounter::Analyzer.run(repo_path: repo, min_loc: 1, since: nil).rows
    controller = rows.find { |r| r[:file] == "app/controllers/posts_controller.rb" }
    model = rows.find { |r| r[:file] == "app/models/post.rb" }

    assert controller[:crud_profile][:crud_only]
    assert_nil model[:crud_profile]
  ensure
    FileUtils.remove_entry(repo) if repo && Dir.exist?(repo)
  end

  private

  def build_repo(dir, files)
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

  def analyze(min_loc: 1)
    Linecounter::Analyzer.run(repo_path: @repo, min_loc: min_loc, since: nil)
  end

  def files
    analyze.rows.map { |r| r[:file] }
  end
end
