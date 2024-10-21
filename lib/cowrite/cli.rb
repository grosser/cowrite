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
      model = ENV.fetch("MODEL", "gpt-4o")
      cowrite = Cowrite.new(url: url, api_key: api_key, model: model)

      abort "Use only first argument for prompt" if argv.size != 1 # TODO: remove
      prompt = ARGV[0]

      files = cowrite.files prompt
      answer = prompt "Found #{files.size} files to iterate", ["continue", "list"]
      case answer
      when "continue" # do nothing
      when "list" then
        warn files
        abort unless prompt("Continue ?", ["yes", "no"]) == "yes"
      else raise
      end

      # prompting on main thread so we can go 1-by-1
      finish = -> (file, _, diff) do
        # ask user if diff is fine
        answer = prompt "Diff for #{file}:\n#{diff}Apply diff to #{file}?", ["yes", "no"]
        return unless answer == "yes"

        with_content_in_file(diff.strip + "\n") do |path|
          # apply diff
          cmd = "patch -R #{file} < #{path}"
          out = `#{cmd}`
          return if $?.success?

          # give the user a chance to copy the tempfile or modify it
          warn "Patch failed:\n#{cmd}\n#{out}"
          abort unless prompt("Continue ?", ["yes", "no"]) == "yes"
        end
      end

      # TODO: --parallel instead of env
      Parallel.each files, finish: finish, threads: Integer(ENV["PARALLEL"] || "10"), progress: true do |file|
        cowrite.diff file, prompt
      end
    end

    private

    def with_content_in_file(content)
      Tempfile.create("cowrite-diff") do |f|
        f.write content
        f.close
        yield f.path
      end
    end

    # prompt user with questions and answers until they pick one of them
    # also supports replying with the first letter of the answer
    def prompt(question, answers)
      colored_answers = answers.map { |a| color(:underline, a[0]) + a[1...] }.join("/")
      loop do
        warn "#{color_last_line(:blue, question)} [#{colored_answers}]"
        read = STDIN.gets.strip
        return read if answers.include?(read)
        if (a = answers.map { |a| a[0] }.index(read))
          return answers[a]
        end
      end
    end

    def color_last_line(color, text)
      lines = text.split("\n")
      lines[-1] = color(color, lines[-1])
      lines.join("\n")
    end

    def color(color, text)
      code =
        case color
        when :underline then 4
        when :blue then 34
        else raise ArgumentError
        end
      "\e[#{code}m#{text}\e[0m"
    end

    def remove_shell_colors(string)
      string.gsub(/\e\[(\d+)(;\d+)*m/, "")
    end
  end
end
