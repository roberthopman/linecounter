module Linecounter
  module BranchAnalyzer
    BRANCH_TOKENS = [
      [:if, "if condition", /\bif\b/],
      [:elsif, "elsif branch", /\belsif\b/],
      [:unless, "unless condition", /\bunless\b/],
      [:case, "case expression", /\bcase\b/],
      [:when, "when branch", /\bwhen\b/],
      [:while, "while loop", /\bwhile\b/],
      [:until, "until loop", /\buntil\b/],
      [:rescue, "rescue handler", /\brescue\b/],
      [:ensure, "ensure block", /\bensure\b/],
      [:begin, "begin block", /\bbegin\b/],
      [:and, "logical AND (&&)", /&&/],
      [:or, "logical OR (||)", /\|\|/],
      [:ternary, "ternary operator (?)", /\?/],
      [:return, "return statement", /\breturn\b/]
    ].freeze

    module_function

    def breakdown(content)
      BRANCH_TOKENS.each_with_object({}) do |(name, _label, re), acc|
        acc[name] = content.scan(re).size
      end
    end
  end
end
