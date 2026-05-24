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

    CONSTANT_RE = /^\s*[A-Z][A-Z0-9_]*\s*=/
    DEF_SELF_RE = /^\s*def\s+self\./
    DEF_RE = /^\s*def\s+([a-zA-Z_]\w*)\b/
    CLASS_SELF_RE = /^\s*class\s+<<\s*self\b/
    VISIBILITY_RE = /^\s*(public|protected|private)\b/
    END_RE = /^\s*end\b/
    BLOCK_OPEN_RE = /^\s*(class|module|def|if|unless|case|while|until|begin|for)\b/

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
      { key: :public_instance_method_def, type: :public_methods, label: "public def", match: ->(s, v) { v == :public && s.match?(DEF_RE) } },
      { key: :protected_instance_method_def, type: :protected_methods, label: "protected def", match: ->(s, v) { v == :protected && s.match?(DEF_RE) } },
      { key: :private_instance_method_def, type: :private_methods, label: "private def", match: ->(s, v) { v == :private && s.match?(DEF_RE) } },
      { key: :initializer_def, type: :initializer, label: "initialize", match: ->(s, _v) { s.match?(/^\s*def\s+initialize\b/) } }
    ].freeze

    module_function

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
      visibility = :public
      stack = []
      lines = content.each_line.to_a

      lines.each_with_index do |line, idx|
        strip = line.strip
        next if strip.empty? || strip.start_with?("#")

        if (m = strip.match(VISIBILITY_RE))
          visibility = m[1].to_sym
          next
        end

        STRUCTURE_ITEMS.each do |item|
          next unless item[:match].call(strip, visibility)

          span = statement_span(lines, idx)
          item_counts[item[:key]] += 1
          item_loc_sums[item[:key]] += span
          type_counts[item[:type]] += 1
        end

        if strip.match?(CLASS_SELF_RE)
          stack << :singleton
          next
        end

        if strip.match?(END_RE)
          stack.pop
          next
        end

        stack << :block if strip.match?(BLOCK_OPEN_RE)
      end

      [type_counts, item_counts, item_loc_sums]
    end
  end
end
