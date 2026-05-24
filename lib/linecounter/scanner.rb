require_relative "git"

module Linecounter
  module Scanner
    EXTS = %w[rb].freeze

    module_function

    def loc(content)
      content.each_line.count { |l| !l.strip.empty? }
    end

    def ruby_files(repo_path)
      Git.run("git", "-C", repo_path, "ls-files")
        .lines
        .map(&:strip)
        .select { |f| EXTS.include?(File.extname(f).delete(".")) }
        .reject { |f| File.basename(f) == "schema.rb" }
    end
  end
end
