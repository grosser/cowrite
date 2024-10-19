# frozen_string_literal: true

require "shellwords"
require "parallel"
require "tempfile"

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
      # TODO: show user diff and ask to apply
      # prompting on main thread so we can go 1-by-1
      finish = -> (file, _, content) do
        # answer = prompt "Apply this diff to #{file}\n#{diff}", ["yes", "no"]
        # if answer == "yes"
        #   Tempfile.create("cowrite-diff") do |f|
        #     f.write diff.strip + "\n"
        #     f.close
        #     out = `patch #{file} < #{f.path}`
        #     abort "Patch failed:\n#{out}" unless $?.success?
        #   end
        # end
        File.write file, content
      end
      Parallel.each files, finish: , threads: Integer(ENV["PARALLEL"] || "10"), progress: true do |file|
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
