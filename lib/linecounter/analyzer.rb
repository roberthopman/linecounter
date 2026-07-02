require_relative "scanner"
require_relative "git"
require_relative "branch_analyzer"
require_relative "structure_analyzer"

module Linecounter
  Result = Struct.new(
    :rows,
    :structure_overview,
    :structure_item_loc_overview,
    :structure_item_counts_overview,
    keyword_init: true
  )

  module Analyzer
    CONTROLLER_PATH = %r{app/controllers/.*_controller\.rb\z}

    module_function

    def run(repo_path:, min_loc:, since:, churn: true)
      rows = []
      structure_overview = Hash.new(0)
      structure_item_loc_overview = Hash.new(0)
      structure_item_counts_overview = Hash.new(0)

      Scanner.ruby_files(repo_path).each do |file|
        content = File.read(File.join(repo_path, file)) rescue next
        size = Scanner.loc(content)
        next if size < min_loc

        breakdown = BranchAnalyzer.breakdown(content)
        b = breakdown.values.sum
        c = churn ? Git.churn(repo_path, file, since) : 0
        structures, structure_item_counts, structure_item_loc = StructureAnalyzer.counts(content)
        structures.each { |k, v| structure_overview[k] += v }
        structure_item_loc.each { |k, v| structure_item_loc_overview[k] += v }
        structure_item_counts.each { |k, v| structure_item_counts_overview[k] += v }

        crud_profile = file.match?(CONTROLLER_PATH) ? StructureAnalyzer.crud_profile(content) : nil

        rows << {
          file: file,
          loc: size,
          branches: b,
          branch_breakdown: breakdown,
          structures: structures,
          structure_item_counts: structure_item_counts,
          structure_item_loc: structure_item_loc,
          crud_profile: crud_profile,
          churn: c
        }
      end

      rows.sort_by! { |r| [-r[:churn], -r[:branches], -r[:loc]] }

      Result.new(
        rows: rows,
        structure_overview: structure_overview,
        structure_item_loc_overview: structure_item_loc_overview,
        structure_item_counts_overview: structure_item_counts_overview
      )
    end
  end
end
