require "prism"

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

    # Item metadata: key -> (type, human label). Counts are keyed by item; each
    # item rolls up into exactly one type.
    STRUCTURE_ITEMS = [
      { key: :include, type: :module_inclusion, label: "include" },
      { key: :extend, type: :module_inclusion, label: "extend" },
      { key: :prepend, type: :module_inclusion, label: "prepend" },
      { key: :constant_assignment, type: :constants, label: "CONSTANT =" },

      { key: :has_many, type: :association, label: "has_many" },
      { key: :has_one, type: :association, label: "has_one" },
      { key: :belongs_to, type: :association, label: "belongs_to" },
      { key: :habtm, type: :association, label: "has_and_belongs_to_many" },
      { key: :has_one_attached, type: :association, label: "has_one_attached" },
      { key: :has_many_attached, type: :association, label: "has_many_attached" },

      { key: :scope, type: :macros, label: "scope" },
      { key: :validates, type: :macros, label: "validates" },
      { key: :validate, type: :macros, label: "validate" },
      { key: :before_callback, type: :macros, label: "before_*" },
      { key: :after_callback, type: :macros, label: "after_*" },
      { key: :around_callback, type: :macros, label: "around_*" },
      { key: :enum, type: :macros, label: "enum" },
      { key: :serialize, type: :macros, label: "serialize" },
      { key: :store, type: :macros, label: "store" },
      { key: :store_accessor, type: :macros, label: "store_accessor" },

      { key: :public_attr_reader, type: :public_attribute_macros, label: "public attr_reader" },
      { key: :public_attr_writer, type: :public_attribute_macros, label: "public attr_writer" },
      { key: :public_attr_accessor, type: :public_attribute_macros, label: "public attr_accessor" },
      { key: :protected_attr_reader, type: :protected_attribute_macros, label: "protected attr_reader" },
      { key: :protected_attr_writer, type: :protected_attribute_macros, label: "protected attr_writer" },
      { key: :protected_attr_accessor, type: :protected_attribute_macros, label: "protected attr_accessor" },
      { key: :private_attr_reader, type: :private_attribute_macros, label: "private attr_reader" },
      { key: :private_attr_writer, type: :private_attribute_macros, label: "private attr_writer" },
      { key: :private_attr_accessor, type: :private_attribute_macros, label: "private attr_accessor" },

      { key: :public_delegate, type: :public_delegate, label: "public delegate" },
      { key: :private_delegate, type: :private_delegate, label: "private delegate" },

      { key: :public_class_method_def, type: :public_class_methods, label: "public class def" },
      { key: :public_instance_method_def, type: :public_methods, label: "public def" },
      { key: :protected_instance_method_def, type: :protected_methods, label: "protected def" },
      { key: :private_instance_method_def, type: :private_methods, label: "private def" },
      { key: :initializer_def, type: :initializer, label: "initialize" }
    ].freeze

    KEY_TO_TYPE = STRUCTURE_ITEMS.each_with_object({}) { |item, h| h[item[:key]] = item[:type] }.freeze

    ASSOCIATION_KEYS = {
      has_many: :has_many, has_one: :has_one, belongs_to: :belongs_to,
      has_and_belongs_to_many: :habtm, has_one_attached: :has_one_attached,
      has_many_attached: :has_many_attached
    }.freeze

    PLAIN_MACROS = %i[scope validates validate enum serialize store store_accessor].freeze
    MODULE_INCLUSION = %i[include extend prepend].freeze
    ATTRIBUTE_MACROS = %i[attr_reader attr_writer attr_accessor].freeze
    VISIBILITY_NAMES = %i[public protected private].freeze

    # Walks the AST tracking visibility per class/module scope, so each method,
    # macro, and constant is attributed accurately at the structure level only
    # (declarations inside method bodies are not miscounted).
    class StructureVisitor < Prism::Visitor
      attr_reader :type_counts, :item_counts, :item_loc_sums

      def initialize
        super
        @type_counts = Hash.new(0)
        @item_counts = Hash.new(0)
        @item_loc_sums = Hash.new(0)
        @visibility = [:public]
        @method_depth = 0
        @singleton_depth = 0
        @forced_visibility = nil
      end

      def visit_class_node(node)
        with_scope { super }
      end

      def visit_module_node(node)
        with_scope { super }
      end

      def visit_singleton_class_node(node)
        @singleton_depth += 1
        with_scope { super }
        @singleton_depth -= 1
      end

      def visit_def_node(node)
        classify_def(node) if @method_depth.zero?
        @method_depth += 1
        super
        @method_depth -= 1
      end

      def visit_constant_write_node(node)
        record(:constant_assignment, node) if @method_depth.zero?
        super
      end

      def visit_constant_path_write_node(node)
        record(:constant_assignment, node) if @method_depth.zero?
        super
      end

      def visit_call_node(node)
        return super unless node.receiver.nil?

        name = node.name
        if VISIBILITY_NAMES.include?(name)
          handle_visibility(node, name)
        else
          record(macro_key(name), node) if @method_depth.zero?
          super
        end
      end

      private

      def current_visibility
        @forced_visibility || @visibility.last
      end

      def with_scope
        @visibility.push(:public)
        saved_depth = @method_depth
        @method_depth = 0
        yield
        @method_depth = saved_depth
        @visibility.pop
      end

      def handle_visibility(node, name)
        args = node.arguments&.arguments || []
        if args.empty?
          @visibility[-1] = name if @method_depth.zero?
          # No meaningful children to record.
        else
          previous = @forced_visibility
          @forced_visibility = name
          super_visit(node)
          @forced_visibility = previous
        end
      end

      # Visit children of a node without re-dispatching the node itself.
      def super_visit(node)
        node.compact_child_nodes.each { |child| child.accept(self) }
      end

      def classify_def(node)
        if node.receiver.is_a?(Prism::SelfNode) || @singleton_depth.positive?
          record(:public_class_method_def, node)
        elsif node.name == :initialize
          record(:initializer_def, node)
        else
          record(VISIBILITY_DEF_KEYS.fetch(current_visibility), node)
        end
      end

      VISIBILITY_DEF_KEYS = {
        public: :public_instance_method_def,
        protected: :protected_instance_method_def,
        private: :private_instance_method_def
      }.freeze

      def macro_key(name)
        return name if MODULE_INCLUSION.include?(name)
        return ASSOCIATION_KEYS[name] if ASSOCIATION_KEYS.key?(name)
        return name if PLAIN_MACROS.include?(name)
        return :"#{current_visibility}_attr_#{name.to_s.delete_prefix("attr_")}" if ATTRIBUTE_MACROS.include?(name)
        return current_visibility == :private ? :private_delegate : :public_delegate if name == :delegate

        s = name.to_s
        return :before_callback if s.start_with?("before_")
        return :after_callback if s.start_with?("after_")
        return :around_callback if s.start_with?("around_")

        nil
      end

      def record(key, node)
        type = key && KEY_TO_TYPE[key]
        return unless type

        @item_counts[key] += 1
        @item_loc_sums[key] += node.location.end_line - node.location.start_line + 1
        @type_counts[type] += 1
      end
    end

    module_function

    def counts(content)
      visitor = StructureVisitor.new
      Prism.parse(content).value.accept(visitor)
      [visitor.type_counts, visitor.item_counts, visitor.item_loc_sums]
    end
  end
end
