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
