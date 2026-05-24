require "optparse"
require_relative "git"
require_relative "analyzer"
require_relative "report"

module Linecounter
  module CLI
    DEFAULTS = {
      top: 20,
      since: nil,
      json: false,
      min_loc: 20,
      show_branch_count: false,
      show_structure_overview: false,
      show_detailed_structure: false,
      repo: nil
    }.freeze

    module_function

    def run(argv)
      options = DEFAULTS.dup
      build_parser(options).parse!(argv)

      if options[:repo].nil?
        puts "--repo PATH is required. Path to a git repo to scan."
        exit 1
      end

      options[:since] = Git.parse_since(options[:since])

      repo_path = File.expand_path(options[:repo])
      abort "Not inside a git repository: #{repo_path}" unless Git.repo?(repo_path)

      result = Analyzer.run(repo_path: repo_path, min_loc: options[:min_loc], since: options[:since])
      Report.render(result, options)
    end

    def build_parser(options)
      OptionParser.new do |o|
        o.banner = "Usage: linecounter [options]"
        o.separator ""
        o.separator "Options:"
        o.on("--top N", Integer, "Show top N rows (default: 20).") { |v| options[:top] = v }
        o.on("--since STR", String, "Limit churn to commits since date. Supports git-parseable dates in YYYY-MM-DD (e.g., '2025-01-01'), other git-parseable strings (e.g., 'last friday'), and relative forms: 'N.days.ago', 'N.weeks.ago', 'N.hours.ago', 'N.months.ago', 'N.years.ago', plus 'today'/'yesterday'.") { |v| options[:since] = v }
        o.on("--min-loc N", Integer, "Exclude files below N non-empty lines (default: 20).") { |v| options[:min_loc] = v }
        o.on("--repo PATH", String, "Path to a git repo to scan (required).") { |v| options[:repo] = v }
        o.on("--json", "Output JSON instead of text.") { options[:json] = true }
        o.on("--show-branch-count", "Show per-branch keyword breakdown under each file.") { options[:show_branch_count] = true }
        o.on("--show-structure-overview", "Show a summary of class structure counts across all files, including avg_loc_per_item (avg statement lines per item).") { options[:show_structure_overview] = true }
        o.on("--show-interaction-overview", "Alias for --show-structure-overview.") { options[:show_structure_overview] = true }
        o.on("--detailed-structure", "Show overall structure averages (avg lines per item) for each regex item across all files.") { options[:show_detailed_structure] = true }
        o.on("-h", "--help", "Show this help.") { puts o; exit }
        o.separator ""
        o.separator "Examples:"
        o.separator "  linecounter --repo /path/to/repo"
        o.separator "  linecounter --repo /path/to/repo --top 50"
        o.separator "  linecounter --repo /path/to/repo --since 2025-01-01"
        o.separator "  linecounter --repo /path/to/repo --since 2.weeks.ago"
        o.separator "  linecounter --repo /path/to/repo --min-loc 50"
        o.separator "  linecounter --repo /path/to/repo --show-branch-count"
        o.separator "  linecounter --repo /path/to/repo --show-structure-overview"
        o.separator "  linecounter --repo /path/to/repo --detailed-structure"
        o.separator "  linecounter --repo /path/to/repo --json"
        o.separator "  linecounter --repo /path/to/repo --top 30 --since 3.months.ago"
      end
    end
  end
end
