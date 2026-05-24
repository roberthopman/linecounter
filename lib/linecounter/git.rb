require "open3"
require "time"

module Linecounter
  module Git
    module_function

    def run(*cmd)
      stdout, _, ok = Open3.capture3(*cmd)
      ok ? stdout : ""
    end

    def repo?(repo_path)
      system("git", "-C", repo_path, "rev-parse", "--is-inside-work-tree", out: File::NULL, err: File::NULL)
    end

    def churn(repo_path, file, since)
      cmd = ["git", "-C", repo_path, "log", "--follow", "--pretty=oneline"]
      cmd += ["--since", since] if since
      cmd += ["--", file]
      run(*cmd).lines.count
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
  end
end
