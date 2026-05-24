require_relative "../test_helper"
require "linecounter"

class ScannerTest < Minitest::Test
  def test_loc_ignores_blank_and_whitespace_only_lines
    assert_equal 2, Linecounter::Scanner.loc("a\n\n  \nb\n")
  end

  def test_loc_counts_final_line_without_newline
    assert_equal 2, Linecounter::Scanner.loc("x\ny")
  end

  def test_loc_empty_string
    assert_equal 0, Linecounter::Scanner.loc("")
  end

  def test_ruby_files_lists_tracked_rb_excluding_schema
    Dir.mktmpdir("linecounter-scanner") do |repo|
      RepoBuilder.build(repo)
      assert_equal(
        ["app/models/widget.rb", "app/services/calc.rb", "lib/util.rb"],
        Linecounter::Scanner.ruby_files(repo)
      )
    end
  end
end
