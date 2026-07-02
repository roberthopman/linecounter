require "json"
require "time"
require_relative "branch_analyzer"
require_relative "structure_analyzer"

module Linecounter
  module Report
    module_function

    def render(result, options)
      if options[:json]
        json(result, options)
      else
        text(result, options)
      end
    end

    def json(result, options)
      rows = result.rows
      payload = {
        generated_at: Time.now.utc.iso8601,
        files_scanned: rows.size,
        top: rows.first(options[:top])
      }
      unless options[:show_branch_count]
        payload[:top] = payload[:top].map { |r| r.reject { |k, _| k == :branch_breakdown } }
      end
      if options[:show_structure_overview]
        payload[:structure_overview] = result.structure_overview
        payload[:structure_loc_overview] = type_loc_overview(result)
      end
      if options[:show_detailed_structure]
        payload[:structure_item_counts_overview] = result.structure_item_counts_overview
        payload[:structure_item_loc_overview] = result.structure_item_loc_overview
      end
      unless options[:show_detailed_structure]
        payload[:top] = payload[:top].map { |r| r.reject { |k, _| k == :structure_item_loc || k == :structure_item_counts } }
      end
      payload[:top] = payload[:top].map { |r| r.reject { |k, _| k == :crud_profile } }
      if options[:crud_only_controllers]
        payload[:crud_only_controllers] = crud_only_controllers(rows).map do |r|
          { file: r[:file], actions: r[:crud_profile][:actions] }
        end
      end
      if options[:non_crud_controllers]
        payload[:non_crud_controllers] = non_crud_controllers(rows).map do |r|
          { file: r[:file], actions: r[:crud_profile][:actions], extra_actions: r[:crud_profile][:extra_actions] }
        end
      end
      puts JSON.pretty_generate(payload)
    end

    def text(result, options)
      rows = result.rows
      puts "Ruby Quality Signals"
      puts "Files scanned: #{rows.size}"
      puts
      puts "Column descriptions:"
      puts "  Churn    = total git commits touching the file (optionally since --since)."
      puts "  Branches = count of control-flow tokens (sum of per-keyword counts)."
      puts "  LOC      = non-empty lines of code in the file."
      puts "  File     = repository-relative path."
      puts
      puts "%-6s %-8s %-6s %s" % ["Churn", "Branches", "LOC", "File"]

      rows.first(options[:top]).each do |r|
        puts "%-6d %-8d %-6d %s" % [r[:churn], r[:branches], r[:loc], r[:file]]
        if options[:show_branch_count]
          breakdown = r[:branch_breakdown]
          detail = BranchAnalyzer::BRANCH_TOKENS.map { |name, label, _| "#{label}=#{breakdown[name]}" }.join(" | ")
          puts "  #{detail}"
        end
      end

      if options[:show_structure_overview]
        puts
        puts "Structure overview (all scanned files):"
        StructureAnalyzer::STRUCTURE_ORDER.each do |key|
          count = result.structure_overview[key]
          avg_loc_per_item = count.zero? ? 0.0 : (type_loc_sum(result, key).to_f / count)
          puts "%-26s count=%-4d avg_loc_per_item=%0.2f" % [key, count, avg_loc_per_item]
        end
      end

      if options[:show_detailed_structure]
        puts
        puts "Detailed structure (all scanned files):"
        StructureAnalyzer::STRUCTURE_ORDER.each do |type|
          items = StructureAnalyzer::STRUCTURE_ITEMS.select { |item| item[:type] == type }
          next if items.empty?
          lines = items.map do |item|
            count = result.structure_item_counts_overview[item[:key]]
            next if count.zero?
            avg = result.structure_item_loc_overview[item[:key]].to_f / count
            "  %-26s count=%-4d avg_loc_per_item=%0.2f" % [item[:label], count, avg]
          end.compact
          next if lines.empty?
          puts type
          lines.each { |line| puts line }
        end
      end

      if options[:crud_only_controllers]
        controllers = rows.select { |r| r[:crud_profile] }
        crud_only = crud_only_controllers(rows)
        puts
        puts "CRUD-only controllers:"
        puts "Controllers scanned: #{controllers.size}"
        puts "CRUD-only: #{crud_only.size}"
        puts
        crud_only.each do |r|
          puts "  %s  %s" % [r[:file], r[:crud_profile][:actions].join(", ")]
        end
      end

      if options[:non_crud_controllers]
        controllers = rows.select { |r| r[:crud_profile] }
        non_crud = non_crud_controllers(rows)
        puts
        puts "Non-CRUD controllers:"
        puts "Controllers scanned: #{controllers.size}"
        puts "Non-CRUD: #{non_crud.size}"
        puts
        non_crud.each do |r|
          puts "  %s  %s" % [r[:file], r[:crud_profile][:extra_actions].join(", ")]
        end
      end
    end

    # Rows for controllers whose public actions are all standard RESTful
    # actions, sorted by path for stable output.
    def crud_only_controllers(rows)
      rows
        .select { |r| r[:crud_profile]&.fetch(:crud_only) }
        .sort_by { |r| r[:file] }
    end

    # Rows for controllers that expose at least one custom (non-RESTful) public
    # action, sorted by path for stable output.
    def non_crud_controllers(rows)
      rows
        .select { |r| r[:crud_profile] && !r[:crud_profile][:crud_only] }
        .sort_by { |r| r[:file] }
    end

    # Total statement LOC for a structure type, summed from its items. The
    # per-item LOC is item-keyed, so it must be rolled up by type here rather
    # than indexed directly by the type symbol.
    def type_loc_sum(result, type)
      StructureAnalyzer::STRUCTURE_ITEMS
        .select { |item| item[:type] == type }
        .sum { |item| result.structure_item_loc_overview[item[:key]] }
    end

    def type_loc_overview(result)
      result.structure_overview.keys.each_with_object({}) do |type, acc|
        acc[type] = type_loc_sum(result, type)
      end
    end
  end
end
