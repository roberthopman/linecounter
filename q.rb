#!/usr/bin/env ruby
# q.rb
# Lists Ruby files with lines of code, churn, branching, and avg loc per item.

require "optparse"
require "json"
require "open3"
require "time"

EXTS = %w[rb].freeze

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

options = {
  top: 20,
  since: nil,
  json: false,
  min_loc: 20,
  show_branch_count: false,
  show_structure_overview: false,
  show_detailed_structure: false,
  repo: nil
}

parser = OptionParser.new do |o|
  o.banner = "Usage: ruby q.rb [options]"
  o.separator ""
  o.separator "Options:"
  o.on("--top N", Integer, "Show top N rows (default: 20).") { |v| options[:top] = v }
  o.on("--since STR", String, "Limit churn to commits since date. Supports git-parseable dates in YYYY-MM-DD (e.g., '2025-01-01'), other git-parseable strings (e.g., 'last friday'), and relative forms: 'N.days.ago', 'N.weeks.ago', 'N.hours.ago', 'N.months.ago', 'N.years.ago', plus 'today'/'yesterday'.") { |v| options[:since] = v }
  o.on("--min-loc N", Integer, "Exclude files below N non-empty lines (default: 20).") { |v| options[:min_loc] = v }
  o.on("--repo PATH", String, "Path to a git repo to scan (default: current directory).") { |v| options[:repo] = v }
  o.on("--json", "Output JSON instead of text.") { options[:json] = true }
  o.on("--show-branch-count", "Show per-branch keyword breakdown under each file.") { options[:show_branch_count] = true }
  o.on("--show-structure-overview", "Show a summary of class structure counts across all files, including avg_loc_per_item (avg statement lines per item).") { options[:show_structure_overview] = true }
  o.on("--show-interaction-overview", "Alias for --show-structure-overview.") { options[:show_structure_overview] = true }
  o.on("--detailed-structure", "Show overall structure averages (avg lines per item) for each regex item across all files.") { options[:show_detailed_structure] = true }
  o.on("-h", "--help", "Show this help.") { puts o; exit }
  o.separator ""
  o.separator "Examples:"
  o.separator "  ruby q.rb"
  o.separator "  ruby q.rb --top 50"
  o.separator "  ruby q.rb --since 2025-01-01"
  o.separator "  ruby q.rb --since 2.weeks.ago"
  o.separator "  ruby q.rb --min-loc 50"
  o.separator "  ruby q.rb --show-branch-count"
  o.separator "  ruby q.rb --show-structure-overview"
  o.separator "  ruby q.rb --detailed-structure"
  o.separator "  ruby q.rb --json"
  o.separator "  ruby q.rb --repo /path/to/repo --top 30 --since 3.months.ago"
end

parser.parse!

if options[:repo].nil?
  puts "--repo PATH is required. Path to a git repo to scan."
  exit 1
end

def parse_since(str)
  return nil if str.nil?
  return str if str.strip.empty?

  normalized = str.strip.downcase
  if (m = normalized.match(/\A(\d+)\.(days?|weeks?|months?|years?|hours?)\.ago\z/))
    count = m[1].to_i
    unit = m[2]
    seconds =
      case unit
      when "day", "days" then 86_400
      when "week", "weeks" then 7 * 86_400
      when "hour", "hours" then 3_600
      when "month", "months" then 30 * 86_400
      when "year", "years" then 365 * 86_400
      else 0
      end
    return (Time.now - (count * seconds)).utc.iso8601
  end

  case normalized
  when "today" then Time.now.utc.iso8601
  when "yesterday" then (Time.now - 86_400).utc.iso8601
  else str
  end
end

options[:since] = parse_since(options[:since])

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

ASSOCIATION_RE = /\b(has_many|has_one|belongs_to|has_and_belongs_to_many|has_one_attached|has_many_attached)\b/
MACRO_RE = /\b(scope|validates|validate|before_|after_|around_|enum|serialize|store|store_accessor)\b/
ATTRIBUTE_RE = /\battr_(reader|writer|accessor)\b/
DELEGATE_RE = /\bdelegate\b/
MODULE_INCLUDE_RE = /\b(include|extend|prepend)\b/
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

def structure_counts(content)
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

def run(*cmd)
  stdout, _, ok = Open3.capture3(*cmd)
  ok ? stdout : ""
end

repo_path = File.expand_path(options[:repo])
unless system("git", "-C", repo_path, "rev-parse", "--is-inside-work-tree", out: File::NULL, err: File::NULL)
  abort "Not inside a git repository: #{repo_path}"
end

files =
  run("git", "-C", repo_path, "ls-files")
    .lines
    .map(&:strip)
    .select { |f| EXTS.include?(File.extname(f).delete(".")) }
    .reject { |f| File.basename(f) == "schema.rb" }

def loc(content)
  content.each_line.count { |l| !l.strip.empty? }
end

def branch_breakdown(content)
  BRANCH_TOKENS.each_with_object({}) do |(name, _label, re), acc|
    acc[name] = content.scan(re).size
  end
end

def churn(repo_path, file, since)
  cmd = ["git", "-C", repo_path, "log", "--follow", "--pretty=oneline"]
  cmd += ["--since", since] if since
  cmd += ["--", file]
  run(*cmd).lines.count
end

rows = []
structure_overview = Hash.new(0)
structure_item_loc_overview = Hash.new(0)
structure_item_counts_overview = Hash.new(0)

files.each do |file|
  content = File.read(File.join(repo_path, file)) rescue next
  size = loc(content)
  next if size < options[:min_loc]

  breakdown = branch_breakdown(content)
  b = breakdown.values.sum
  c = churn(repo_path, file, options[:since])
  structures, structure_item_counts, structure_item_loc = structure_counts(content)
  structures.each { |k, v| structure_overview[k] += v }
  structure_item_loc.each { |k, v| structure_item_loc_overview[k] += v }
  structure_item_counts.each { |k, v| structure_item_counts_overview[k] += v }

  rows << {
    file: file,
    loc: size,
    branches: b,
    branch_breakdown: breakdown,
    structures: structures,
    structure_item_counts: structure_item_counts,
    structure_item_loc: structure_item_loc,
    churn: c
  }
end

rows.sort_by! { |r| [-r[:churn], -r[:branches], -r[:loc]] }

if options[:json]
  payload = {
    generated_at: Time.now.utc.iso8601,
    files_scanned: rows.size,
    top: rows.first(options[:top])
  }
  unless options[:show_branch_count]
    payload[:top] = payload[:top].map { |r| r.reject { |k, _| k == :branch_breakdown } }
  end
  if options[:show_structure_overview]
    payload[:structure_overview] = structure_overview
    payload[:structure_item_loc_overview] = structure_item_loc_overview
  end
  if options[:show_detailed_structure]
    payload[:structure_item_counts_overview] = structure_item_counts_overview
  end
  unless options[:show_detailed_structure]
    payload[:top] = payload[:top].map { |r| r.reject { |k, _| k == :structure_item_loc || k == :structure_item_counts } }
  end
  puts JSON.pretty_generate(payload)
  exit
end

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
    detail = BRANCH_TOKENS.map { |name, label, _| "#{label}=#{breakdown[name]}" }.join(" | ")
    puts "  #{detail}"
  end
end

if options[:show_structure_overview]
  puts
  puts "Structure overview (all scanned files):"
  STRUCTURE_ORDER.each do |key|
    count = structure_overview[key]
    avg_loc_per_item = count.zero? ? 0.0 : (structure_item_loc_overview[key].to_f / count)
    puts "%-26s count=%-4d avg_loc_per_item=%0.2f" % [key, count, avg_loc_per_item]
  end
end

if options[:show_detailed_structure]
  puts
  puts "Detailed structure (all scanned files):"
  STRUCTURE_ORDER.each do |type|
    items = STRUCTURE_ITEMS.select { |item| item[:type] == type }
    next if items.empty?
    lines = items.map do |item|
      count = structure_item_counts_overview[item[:key]]
      next if count.zero?
      avg = structure_item_loc_overview[item[:key]].to_f / count
      "  %-26s count=%-4d avg_loc_per_item=%0.2f" % [item[:label], count, avg]
    end.compact
    next if lines.empty?
    puts type
    lines.each { |line| puts line }
  end
end
