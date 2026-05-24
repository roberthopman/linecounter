require_relative "../test_helper"
require "linecounter"

class BranchAnalyzerTest < Minitest::Test
  def test_counts_each_control_flow_keyword
    content = "if x\nelsif y\nunless z\ncase w\nwhen 1\nwhile a\nuntil b\nbegin\nrescue\nensure\n"
    b = Linecounter::BranchAnalyzer.breakdown(content)
    assert_equal 1, b[:if]
    assert_equal 1, b[:elsif]
    assert_equal 1, b[:unless]
    assert_equal 1, b[:case]
    assert_equal 1, b[:when]
    assert_equal 1, b[:while]
    assert_equal 1, b[:until]
    assert_equal 1, b[:begin]
    assert_equal 1, b[:rescue]
    assert_equal 1, b[:ensure]
  end

  def test_counts_operators_and_return
    b = Linecounter::BranchAnalyzer.breakdown("a && b || c ? d : e\nreturn z\n")
    assert_equal 1, b[:and]
    assert_equal 1, b[:or]
    assert_equal 1, b[:ternary]
    assert_equal 1, b[:return]
  end

  def test_elsif_does_not_increment_if
    assert_equal 0, Linecounter::BranchAnalyzer.breakdown("elsif y\n")[:if]
  end

  def test_returns_all_token_keys_even_when_zero
    b = Linecounter::BranchAnalyzer.breakdown("x = 1\n")
    expected_keys = Linecounter::BranchAnalyzer::BRANCH_TOKENS.map { |name, _, _| name }
    assert_equal expected_keys.sort, b.keys.sort
    assert(b.values.all?(&:zero?))
  end
end
