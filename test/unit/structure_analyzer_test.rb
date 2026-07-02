require_relative "../test_helper"
require "linecounter"

class StructureAnalyzerTest < Minitest::Test
  SA = Linecounter::StructureAnalyzer

  def test_loc_span_reflects_method_length
    _tc, _ic, loc = SA.counts(<<~RUBY)
      class A
        def big
          a = 1
          b = 2
          a + b
        end
      end
    RUBY
    assert_equal 5, loc[:public_instance_method_def]
  end

  def test_macros_inside_method_bodies_are_not_counted
    _tc, item_counts, = SA.counts(<<~RUBY)
      class A
        has_many :real
        def build
          has_many :fake
          scope :nope
        end
      end
    RUBY
    assert_equal 1, item_counts[:has_many]
    assert_equal 0, item_counts[:scope]
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

  # def self.x is only a class method; def initialize is only the initializer.
  # Neither is also counted as a plain public def (regression test for the
  # step-4 double-count fix). Only `name` is a plain public def here.
  def test_def_self_and_initialize_are_not_counted_as_public_defs
    type_counts, item_counts, = SA.counts(sample)
    assert_equal 1, item_counts[:public_instance_method_def]
    assert_equal 1, type_counts[:public_methods]
    assert_equal 1, item_counts[:public_class_method_def]
    assert_equal 1, item_counts[:initializer_def]
  end

  # Bug A: a `private` in one class must not leak into the next class.
  def test_visibility_does_not_leak_across_classes
    type_counts, = SA.counts(<<~RUBY)
      class A
        private
        def a; end
      end
      class B
        def b; end
        def c; end
      end
    RUBY
    assert_equal 2, type_counts[:public_methods]
    assert_equal 1, type_counts[:private_methods]
  end

  # Bug B: `private def foo` counts foo as private but does not switch the
  # surrounding section to private for following methods.
  def test_inline_private_def_counts_without_flipping_section
    type_counts, item_counts, = SA.counts(<<~RUBY)
      class A
        def pub1; end
        private def helper; end
        def pub2; end
      end
    RUBY
    assert_equal 2, type_counts[:public_methods]
    assert_equal 1, type_counts[:private_methods]
    assert_equal 1, item_counts[:private_instance_method_def]
  end

  def test_inline_private_attr_reader_is_counted_at_that_visibility
    _type_counts, item_counts, = SA.counts(<<~RUBY)
      class A
        private attr_reader :secret
        def pub; end
      end
    RUBY
    assert_equal 1, item_counts[:private_attr_reader]
    assert_equal 1, item_counts[:public_instance_method_def]
  end

  # Nested class opens a fresh public scope and, on its end, restores the
  # enclosing class's section visibility.
  def test_nested_scope_resets_and_restores_visibility
    type_counts, = SA.counts(<<~RUBY)
      class Outer
        private
        def o1; end
        class Inner
          def i; end
        end
        def o2; end
      end
    RUBY
    assert_equal 1, type_counts[:public_methods]   # Inner#i
    assert_equal 2, type_counts[:private_methods]  # Outer#o1, Outer#o2
  end

  # Regression: do/end and control-flow blocks inside a method must not throw
  # off the scope stack and leak visibility.
  def test_blocks_inside_methods_do_not_break_scope
    type_counts, = SA.counts(<<~RUBY)
      class A
        def total
          [1].each do |x|
            next if x.nil?
          end
        end
        private
        def helper
          case 1
          when 1 then :a
          end
        end
      end
      class B
        def pub; end
      end
    RUBY
    assert_equal 2, type_counts[:public_methods]   # A#total, B#pub
    assert_equal 1, type_counts[:private_methods]  # A#helper
  end

  # Bug C: a comparison at line start is not a constant assignment.
  def test_comparison_at_line_start_is_not_a_constant
    _type_counts, item_counts, = SA.counts(<<~RUBY)
      STATUS == :active
      MAX = 10
    RUBY
    assert_equal 1, item_counts[:constant_assignment]
  end

  def test_crud_profile_flags_controller_with_only_standard_actions
    profile = SA.crud_profile(<<~RUBY)
      class PostsController < ApplicationController
        def index; end
        def show; end
        def create; end

        private

        def post_params; end
      end
    RUBY
    assert profile[:crud_only]
    assert_equal %i[index show create], profile[:actions]
    assert_empty profile[:extra_actions]
  end

  def test_crud_profile_reports_extra_public_actions
    profile = SA.crud_profile(<<~RUBY)
      class PostsController < ApplicationController
        def index; end
        def archive; end
      end
    RUBY
    refute profile[:crud_only]
    assert_equal %i[index], profile[:actions]
    assert_equal %i[archive], profile[:extra_actions]
  end

  def test_crud_profile_ignores_private_and_protected_methods
    profile = SA.crud_profile(<<~RUBY)
      class PostsController < ApplicationController
        def index; end

        protected

        def authorize!; end

        private

        def set_post; end
      end
    RUBY
    assert profile[:crud_only]
    assert_equal %i[index], profile[:actions]
  end

  def test_crud_profile_matches_namespaced_controllers
    profile = SA.crud_profile(<<~RUBY)
      module Admin
        class PostsController < ApplicationController
          def index; end
        end
      end
    RUBY
    assert profile[:crud_only]
  end

  def test_crud_profile_returns_nil_for_non_controller_class
    assert_nil SA.crud_profile(<<~RUBY)
      class Post
        def index; end
      end
    RUBY
  end

  def test_crud_profile_returns_nil_for_controller_without_actions
    assert_nil SA.crud_profile(<<~RUBY)
      class ApplicationController < ActionController::Base
        private

        def current_user; end
      end
    RUBY
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
