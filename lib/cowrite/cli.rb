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
      answer = prompt "Found #{files.size} files to iterate", ["continue", "list"]
      case answer
      when "continue" # do nothing
      when "list" then
        puts files
        abort unless prompt("Continue ?", ["yes", "no"]) == "yes"
      else raise
      end


      # TODO: flag instead of env
      Parallel.each files, threads: Integer(ENV["PARALLEL"] || "10"), progress: true do |file|
        cowrite.modify file, prompt
      end
    end

    private

    def prompt(question, answers)
      loop do
        puts "#{question} [#{answers.join("/")}]"
        read = STDIN.gets.strip
        return read if answers.include?(read)
        if (a = answers.map { |a| a[0] }.index(read))
          return answers[a]
        end
      end
    end

    def remove_shell_colors(string)
      string.gsub(/\e\[(\d+)(;\d+)*m/, "")
    end
  end
end
