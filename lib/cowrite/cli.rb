# frozen_string_literal: true

require "shellwords"
require "parallel"

class Cowrite
  class CLI
    def run(argv)
      # get config first so we fail fast
      api_key = ENV.fetch("COWRITE_API_KEY")
      url = ENV.fetch("COWRITE_URL", "https://api.openai.com")
      model = ENV.fetch("MODEL", "gpt-4o-mini")
      cowrite = Cowrite.new(url: url, api_key: api_key, model: model)

      abort "Use only first argument for prompt" if argv.size != 1 # TODO: remove
      prompt = ARGV[0]

      files = cowrite.files prompt
      puts "Found #{files.size} files to iterate [continue/list]"
      abort unless STDIN.gets == "c\n" # TODO: prompt with loop and list support

      # TODO: flag instead of env
      Parallel.each files, threads: Integer(ENV["PARALLEL"] || "10"), progress: true do |file|
        cowrite.modify file, prompt
      end
    end

    private

    def remove_shell_colors(string)
      string.gsub(/\e\[(\d+)(;\d+)*m/, "")
    end
  end
end
