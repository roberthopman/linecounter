require_relative "../test_helper"
require "linecounter"
require "time"

class GitTest < Minitest::Test
  G = Linecounter::Git

  def test_parse_since_nil
    assert_nil G.parse_since(nil)
  end

  def test_parse_since_blank_returns_input_unchanged
    assert_equal "", G.parse_since("")
    assert_equal "   ", G.parse_since("   ")
  end

  def test_parse_since_passes_git_parseable_strings_through
    assert_equal "2025-01-01", G.parse_since("2025-01-01")
    assert_equal "last friday", G.parse_since("last friday")
  end

  def test_parse_since_today_and_yesterday
    assert_in_delta Time.now.to_f, Time.parse(G.parse_since("today")).to_f, 5
    assert_in_delta (Time.now - 86_400).to_f, Time.parse(G.parse_since("yesterday")).to_f, 5
  end

  def test_parse_since_relative_forms
    assert_in_delta (Time.now - 2 * 86_400).to_f, Time.parse(G.parse_since("2.days.ago")).to_f, 5
    assert_in_delta (Time.now - 7 * 86_400).to_f, Time.parse(G.parse_since("1.week.ago")).to_f, 5
    assert_in_delta (Time.now - 3 * 3_600).to_f, Time.parse(G.parse_since("3.hours.ago")).to_f, 5
  end

  def test_parse_since_is_case_insensitive
    assert_in_delta (Time.now - 7 * 86_400).to_f, Time.parse(G.parse_since("1.Week.Ago")).to_f, 5
  end
end
