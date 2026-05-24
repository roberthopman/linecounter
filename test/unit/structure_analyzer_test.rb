require_relative "../test_helper"
require "linecounter"

class StructureAnalyzerTest < Minitest::Test
  SA = Linecounter::StructureAnalyzer

  def test_statement_span_single_line
    assert_equal 1, SA.statement_span(["def foo\n", "end\n"], 0)
  end

  def test_statement_span_trailing_comma_continuation
    lines = ["validates :name,\n", "  presence: true\n", "end\n"]
    assert_equal 2, SA.statement_span(lines, 0)
  end

  def test_statement_span_paren_continuation
    lines = ["foo(\n", "  a,\n", "  b)\n", "end\n"]
    assert_equal 3, SA.statement_span(lines, 0)
  end

  def test_counts_classifies_by_type_and_visibility
    type_counts, item_counts, item_loc = SA.counts(sample)

    assert_equal 1, type_counts[:module_inclusion]
    assert_equal 1, type_counts[:association]
    assert_equal 1, type_counts[:public_class_methods]
    assert_equal 1, type_counts[:initializer]
    assert_equal 1, type_counts[:private_methods]

    assert_equal 1, item_counts[:include]
    assert_equal 1, item_counts[:has_many]
    assert_equal 1, item_counts[:private_instance_method_def]
    assert_equal 1, item_loc[:include]
  end

  # PINNED KNOWN BUG (fix in step 4): "def self." and "def initialize" also
  # match the plain public-def item (DEF_RE), so each is double-counted as a
  # public instance method. Counting self.create + initialize + name = 3.
  def test_counts_pins_def_self_and_initialize_double_count
    type_counts, item_counts, = SA.counts(sample)
    assert_equal 3, item_counts[:public_instance_method_def]
    assert_equal 3, type_counts[:public_methods]
    assert_equal 1, item_counts[:public_class_method_def]
    assert_equal 1, item_counts[:initializer_def]
  end

  private

  def sample
    <<~RUBY
      class Foo
        include Bar
        has_many :things
        def self.create
          1
        end
        def initialize
          2
        end
        def name
          3
        end
        private
        def secret
          4
        end
      end
    RUBY
  end
end
