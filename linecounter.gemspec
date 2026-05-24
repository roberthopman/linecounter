require_relative "lib/linecounter/version"

Gem::Specification.new do |spec|
  spec.name = "linecounter"
  spec.version = Linecounter::VERSION
  spec.authors = ["Robert Hopman"]
  spec.email = ["hopman.r@gmail.com"]

  spec.summary = "Per-file Ruby quality signals: lines of code, churn, branching, and structure."
  spec.description = "linecounter scans a git repository and reports per-file quality signals — " \
                     "non-empty lines of code, git churn, control-flow branching, and class-structure " \
                     "counts with average statement lines per item. Output as text or JSON."
  spec.homepage = "https://github.com/roberthopman/linecounter"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb", "exe/*", "README.md", "LICENSE"]
  spec.bindir = "exe"
  spec.executables = ["linecounter"]
  spec.require_paths = ["lib"]

  spec.add_dependency "prism", ">= 0.19", "< 2"

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
end
