# frozen_string_literal: true
name = "cowrite"
$LOAD_PATH << File.expand_path("lib", __dir__)
require "#{name.tr("-", "/")}/version"

Gem::Specification.new name, Cowrite::VERSION do |s|
  s.summary = "Create changes for a local repository with chatgpt / openai / local llm"
  s.authors = ["Michael Grosser"]
  s.email = "michael@grosser.it"
  s.homepage = "https://github.com/grosser/#{name}"
  s.files = `git ls-files lib/ bin/ MIT-LICENSE`.split("\n")
  s.license = "MIT"
  s.required_ruby_version = ">= 3.1.0" # keep in sync with .github/workflows/actions.yml, and .rubocop.yml
  s.add_dependency "parallel"
  s.add_dependency "ruby-progressbar"
end
