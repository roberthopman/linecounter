module Linecounter
  module StructureAnalyzer
    STRUCTURE_ORDER = [
      :module_inclusion,
      :constants,
      :association,
      :public_attribute_macros,
      :public_delegate,
      :macros,
      :public_class_methods,
      :initializer,
      :public_methods,
      :protected_attribute_macros,
      :protected_methods,
      :private_attribute_macros,
      :private_delegate,
      :private_methods
    ].freeze

    CONSTANT_RE = /^\s*[A-Z][A-Z0-9_]*\s*=(?![=~>])/
    DEF_SELF_RE = /^\s*def\s+self\./
    DEF_RE = /^\s*def\s+([a-zA-Z_]\w*)\b/
    INITIALIZE_RE = /^\s*def\s+initialize\b/
    CLASS_SELF_RE = /^\s*class\s+<<\s*self\b/
    VISIBILITY_RE = /^\s*(public|protected|private)\b/
    END_RE = /^\s*end\b/
    SCOPE_OPEN_RE = /^\s*(class|module)\b/
    CONTROL_OPEN_RE = /^\s*(if|unless|case|while|until|begin|for)\b/
    DO_BLOCK_RE = /\bdo\b(\s*\|[^|]*\|)?\s*\z/
    INLINE_END_RE = /\bend\b\s*\z/
    ENDLESS_DEF_RE = /^\s*def\b.*\)\s*=(?!=)/
    ENDLESS_DEF_NOPAREN_RE = /^\s*def\s+[^\s(]+\s+=(?!=)/

    STRUCTURE_ITEMS = [
      { key: :include, type: :module_inclusion, label: "include", match: ->(s, _v) { s.match?(/\binclude\b/) } },
      { key: :extend, type: :module_inclusion, label: "extend", match: ->(s, _v) { s.match?(/\bextend\b/) } },
      { key: :prepend, type: :module_inclusion, label: "prepend", match: ->(s, _v) { s.match?(/\bprepend\b/) } },
      { key: :constant_assignment, type: :constants, label: "CONSTANT =", match: ->(s, _v) { s.match?(CONSTANT_RE) } },

      { key: :has_many, type: :association, label: "has_many", match: ->(s, _v) { s.match?(/\bhas_many\b/) } },
      { key: :has_one, type: :association, label: "has_one", match: ->(s, _v) { s.match?(/\bhas_one\b/) } },
      { key: :belongs_to, type: :association, label: "belongs_to", match: ->(s, _v) { s.match?(/\bbelongs_to\b/) } },
      { key: :habtm, type: :association, label: "has_and_belongs_to_many", match: ->(s, _v) { s.match?(/\bhas_and_belongs_to_many\b/) } },
      { key: :has_one_attached, type: :association, label: "has_one_attached", match: ->(s, _v) { s.match?(/\bhas_one_attached\b/) } },
      { key: :has_many_attached, type: :association, label: "has_many_attached", match: ->(s, _v) { s.match?(/\bhas_many_attached\b/) } },

      { key: :scope, type: :macros, label: "scope", match: ->(s, _v) { s.match?(/\bscope\b/) } },
      { key: :validates, type: :macros, label: "validates", match: ->(s, _v) { s.match?(/\bvalidates\b/) } },
      { key: :validate, type: :macros, label: "validate", match: ->(s, _v) { s.match?(/\bvalidate\b/) } },
      { key: :before_callback, type: :macros, label: "before_*", match: ->(s, _v) { s.match?(/\bbefore_/) } },
      { key: :after_callback, type: :macros, label: "after_*", match: ->(s, _v) { s.match?(/\bafter_/) } },
      { key: :around_callback, type: :macros, label: "around_*", match: ->(s, _v) { s.match?(/\baround_/) } },
      { key: :enum, type: :macros, label: "enum", match: ->(s, _v) { s.match?(/\benum\b/) } },
      { key: :serialize, type: :macros, label: "serialize", match: ->(s, _v) { s.match?(/\bserialize\b/) } },
      { key: :store, type: :macros, label: "store", match: ->(s, _v) { s.match?(/\bstore\b/) } },
      { key: :store_accessor, type: :macros, label: "store_accessor", match: ->(s, _v) { s.match?(/\bstore_accessor\b/) } },

      { key: :public_attr_reader, type: :public_attribute_macros, label: "public attr_reader", match: ->(s, v) { v == :public && s.match?(/\battr_reader\b/) } },
      { key: :public_attr_writer, type: :public_attribute_macros, label: "public attr_writer", match: ->(s, v) { v == :public && s.match?(/\battr_writer\b/) } },
      { key: :public_attr_accessor, type: :public_attribute_macros, label: "public attr_accessor", match: ->(s, v) { v == :public && s.match?(/\battr_accessor\b/) } },
      { key: :protected_attr_reader, type: :protected_attribute_macros, label: "protected attr_reader", match: ->(s, v) { v == :protected && s.match?(/\battr_reader\b/) } },
      { key: :protected_attr_writer, type: :protected_attribute_macros, label: "protected attr_writer", match: ->(s, v) { v == :protected && s.match?(/\battr_writer\b/) } },
      { key: :protected_attr_accessor, type: :protected_attribute_macros, label: "protected attr_accessor", match: ->(s, v) { v == :protected && s.match?(/\battr_accessor\b/) } },
      { key: :private_attr_reader, type: :private_attribute_macros, label: "private attr_reader", match: ->(s, v) { v == :private && s.match?(/\battr_reader\b/) } },
      { key: :private_attr_writer, type: :private_attribute_macros, label: "private attr_writer", match: ->(s, v) { v == :private && s.match?(/\battr_writer\b/) } },
      { key: :private_attr_accessor, type: :private_attribute_macros, label: "private attr_accessor", match: ->(s, v) { v == :private && s.match?(/\battr_accessor\b/) } },

      { key: :public_delegate, type: :public_delegate, label: "public delegate", match: ->(s, v) { v != :private && s.match?(/\bdelegate\b/) } },
      { key: :private_delegate, type: :private_delegate, label: "private delegate", match: ->(s, v) { v == :private && s.match?(/\bdelegate\b/) } },

      { key: :public_class_method_def, type: :public_class_methods, label: "public class def", match: ->(s, v) { v == :public && s.match?(DEF_SELF_RE) } },
      { key: :public_instance_method_def, type: :public_methods, label: "public def", match: ->(s, v) { v == :public && instance_def?(s) } },
      { key: :protected_instance_method_def, type: :protected_methods, label: "protected def", match: ->(s, v) { v == :protected && instance_def?(s) } },
      { key: :private_instance_method_def, type: :private_methods, label: "private def", match: ->(s, v) { v == :private && instance_def?(s) } },
      { key: :initializer_def, type: :initializer, label: "initialize", match: ->(s, _v) { s.match?(INITIALIZE_RE) } }
    ].freeze

    module_function

    # A plain instance-method definition: `def name`, but not `def self.x`
    # (class method) and not `def initialize` (initializer). Keeping these
    # mutually exclusive prevents a single def from being counted twice.
    def instance_def?(str)
      str.match?(DEF_RE) && !str.match?(DEF_SELF_RE) && !str.match?(INITIALIZE_RE)
    end

    # Endless method (`def foo = expr`, `def foo(x) = expr`) has no `end`, so it
    # must not be treated as opening a block. A setter (`def foo=(v)`) does.
    def endless_def?(str)
      str.match?(ENDLESS_DEF_RE) || str.match?(ENDLESS_DEF_NOPAREN_RE)
    end

    def opens_block?(str)
      return false if endless_def?(str)

      str.match?(/^\s*def\b/) || str.match?(CONTROL_OPEN_RE) || str.match?(DO_BLOCK_RE)
    end

    # True when a line opens and closes its block on the same line, e.g.
    # `def foo; end` or `[1].each { ... }`-style `... do ... end`.
    def one_liner_closed?(str)
      str.match?(INLINE_END_RE) && !str.match?(END_RE)
    end

    # Maintains the visibility-scope stack as we walk the file. Each open
    # class/module/singleton pushes a frame whose visibility starts public;
    # its `end` pops it, restoring the enclosing scope's visibility. Method
    # and control-flow blocks are tracked only so their `end`s don't pop a
    # scope frame by mistake.
    def update_nesting(str, scopes, block_stack)
      if str.match?(CLASS_SELF_RE)
        block_stack.push(:scope)
        scopes.push(:public)
      elsif str.match?(SCOPE_OPEN_RE)
        return if one_liner_closed?(str)

        block_stack.push(:scope)
        scopes.push(:public)
      elsif str.match?(END_RE)
        frame = block_stack.pop
        scopes.pop if frame == :scope && scopes.size > 1
      elsif opens_block?(str) && !one_liner_closed?(str)
        block_stack.push(:other)
      end
    end

    def statement_span(lines, start_idx)
      paren_balance = 0
      i = start_idx
      while i < lines.size
        code = lines[i].split("#", 2).first.to_s
        paren_balance += code.count("(") + code.count("[") + code.count("{")
        paren_balance -= code.count(")") + code.count("]") + code.count("}")
        continued = code.rstrip.end_with?(",", "\\")
        i += 1
        break if paren_balance <= 0 && !continued
      end
      i - start_idx
    end

    def counts(content)
      type_counts = Hash.new(0)
      item_counts = Hash.new(0)
      item_loc_sums = Hash.new(0)
      scopes = [:public]
      block_stack = []
      lines = content.each_line.to_a

      lines.each_with_index do |line, idx|
        strip = line.strip
        next if strip.empty? || strip.start_with?("#")

        effective = strip
        line_visibility = scopes.last

        if (m = strip.match(VISIBILITY_RE))
          rest = strip[m[0].length..].to_s.strip
          if rest.empty?
            # Bare `private` / `protected` / `public` sets the section.
            scopes[-1] = m[1].to_sym
            next
          end
          # Inline modifier (`private def foo`): apply to this line only,
          # without changing the surrounding section's visibility.
          line_visibility = m[1].to_sym
          effective = rest
        end

        STRUCTURE_ITEMS.each do |item|
          next unless item[:match].call(effective, line_visibility)

          span = statement_span(lines, idx)
          item_counts[item[:key]] += 1
          item_loc_sums[item[:key]] += span
          type_counts[item[:type]] += 1
        end

        update_nesting(effective, scopes, block_stack)
      end

      [type_counts, item_counts, item_loc_sums]
    end
  end
end
