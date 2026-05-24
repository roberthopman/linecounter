require "prism"

module Linecounter
  module BranchAnalyzer
    # Buckets of control-flow constructs, in display order. Counted from the
    # parsed AST, so keywords inside strings and comments are never counted.
    BRANCH_TOKENS = [
      [:if, "if condition"],
      [:elsif, "elsif branch"],
      [:unless, "unless condition"],
      [:case, "case expression"],
      [:when, "when branch"],
      [:while, "while loop"],
      [:until, "until loop"],
      [:rescue, "rescue handler"],
      [:ensure, "ensure block"],
      [:begin, "begin block"],
      [:and, "logical AND (&& / and)"],
      [:or, "logical OR (|| / or)"],
      [:ternary, "ternary operator (?:)"],
      [:return, "return statement"]
    ].freeze

    class CountingVisitor < Prism::Visitor
      attr_reader :counts

      def initialize
        super
        @counts = Hash.new(0)
      end

      def visit_if_node(node)
        key =
          if node.if_keyword_loc.nil? then :ternary
          elsif node.if_keyword_loc.slice == "elsif" then :elsif
          else :if
          end
        @counts[key] += 1
        super
      end

      def visit_unless_node(node)
        @counts[:unless] += 1
        super
      end

      def visit_case_node(node)
        @counts[:case] += 1
        super
      end

      def visit_case_match_node(node)
        @counts[:case] += 1
        super
      end

      def visit_when_node(node)
        @counts[:when] += 1
        super
      end

      def visit_in_node(node)
        @counts[:when] += 1
        super
      end

      def visit_while_node(node)
        @counts[:while] += 1
        super
      end

      def visit_until_node(node)
        @counts[:until] += 1
        super
      end

      def visit_rescue_node(node)
        @counts[:rescue] += 1
        super
      end

      def visit_ensure_node(node)
        @counts[:ensure] += 1
        super
      end

      def visit_begin_node(node)
        # Only explicit `begin ... end`; method/block-level rescue produces an
        # implicit BeginNode (no begin keyword) that we don't count.
        @counts[:begin] += 1 if node.begin_keyword_loc
        super
      end

      def visit_and_node(node)
        @counts[:and] += 1
        super
      end

      def visit_or_node(node)
        @counts[:or] += 1
        super
      end

      def visit_return_node(node)
        @counts[:return] += 1
        super
      end
    end

    module_function

    def breakdown(content)
      visitor = CountingVisitor.new
      Prism.parse(content).value.accept(visitor)
      BRANCH_TOKENS.each_with_object({}) { |(name, _label), acc| acc[name] = visitor.counts[name] }
    end
  end
end
