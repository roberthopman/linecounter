require_relative "../test_helper"
require "linecounter"

class BranchAnalyzerTest < Minitest::Test
  B = Linecounter::BranchAnalyzer

  def test_counts_each_control_flow_construct
    src = <<~RUBY
      def m(x)
        if x then 1 elsif x == 2 then 2 else 3 end
        return 0 unless x
        case x
        when 1 then :a
        end
        while x; x -= 1; end
        until x; x += 1; end
        begin
          risky
        rescue => e
          handle(e)
        ensure
          cleanup
        end
        a && b || c
        x ? 1 : 2
      end
    RUBY
    b = B.breakdown(src)
    {
      if: 1, elsif: 1, unless: 1, case: 1, when: 1, while: 1, until: 1,
      begin: 1, rescue: 1, ensure: 1, and: 1, or: 1, ternary: 1, return: 1
    }.each { |k, v| assert_equal v, b[k], "branch #{k}" }
  end

  # Quality wins from AST counting (the regex version got these wrong):
  def test_predicate_method_question_mark_is_not_a_ternary
    assert_equal 0, B.breakdown("x.empty?\nfoo.valid?\n")[:ternary]
  end

  def test_keywords_in_strings_and_comments_are_not_counted
    b = B.breakdown(%(x = "use if and case"\n# unless return while\n))
    assert b.values.all?(&:zero?), b.inspect
  end

  def test_and_or_keywords_count_like_operators
    b = B.breakdown("a and b\nc or d\n")
    assert_equal 1, b[:and]
    assert_equal 1, b[:or]
  end

  def test_method_level_rescue_counts_rescue_not_begin
    b = B.breakdown("def f\n risky\nrescue\n recover\nend\n")
    assert_equal 1, b[:rescue]
    assert_equal 0, b[:begin]
  end

  def test_returns_all_token_keys_even_when_zero
    b = B.breakdown("x = 1\n")
    expected = B::BRANCH_TOKENS.map { |name, _| name }
    assert_equal expected.sort, b.keys.sort
    assert b.values.all?(&:zero?)
  end
end
