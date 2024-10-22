# frozen_string_literal: true

require "shellwords"
require "parallel"
require "tempfile"

class Cowrite
  class CLI
    QUESTION_COLOR = :blue

    def initialize
      super

      # get config first so we fail fast
      api_key = ENV.fetch("COWRITE_API_KEY")
      url = ENV.fetch("COWRITE_URL", "https://api.openai.com")
      model = ENV.fetch("MODEL", "gpt-4o")
      @cowrite = Cowrite.new(url: url, api_key: api_key, model: model)
    end

    def run(argv)
      abort "Use only first argument for prompt" if argv.size != 1 # TODO: remove
      prompt = ARGV[0]

      files = find_files prompt

      # prompting on main thread so we can go 1-by-1
      finish = -> (file, _, diff) do
        # ask user if diff is fine (TODO: add a "no" option and re-prompt somehow)
        # TODO colors
        prompt "Diff for #{file}:\n#{diff}Apply diff to #{file}?", ["yes"]

        with_content_in_file(diff.strip + "\n") do |path|
          # apply diff (force sus changes, do not make backups)
          cmd = "patch -f --posix #{file} < #{path}"
          out = `#{cmd}`
          return if $?.success?

          # give the user a chance to copy the tempfile or modify it
          warn "Patch failed:\n#{cmd}\n#{out}"
          prompt "Continue ?", ["yes"]
        end
      end

      # TODO: --parallel instead of env
      # produce diffs in parallel since it is slow
      Parallel.each files, finish: finish, threads: Integer(ENV["PARALLEL"] || "10"), progress: true do |file|
        @cowrite.diff file, prompt
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

    def find_files(prompt)
      files = @cowrite.files prompt
      files.each_with_index { |f, i| warn "#{i}: #{f}" } # needs to match choose_files logic
      answer = prompt("Accept #{files.size} files to iterate ?", ["yes", "choose"])
      answer == "choose" ? choose_files(files) : files
    end

    # let user select for index of given files or select whatever files they want via path
    def choose_files(files)
      answer = prompt_freeform("Enter index or path of files command separated")
      chosen = answer.split(/\s?,\s?/)
      abort "No files selected" if chosen.empty?
      chosen =
        files.each_with_index.filter_map { |f, i| f if chosen.include?(i.to_s) } + # index
        chosen.grep_v(/^\d+$/) # path
      missing = chosen.reject { |f| File.exist?(f) }
      abort "Files #{missing} do not exist" if missing.any?
      chosen
    end

    # prompt user with questions and answers until they pick one of them
    # also supports replying with the first letter of the answer
    def prompt(question, answers)
      colored_answers = answers.map { |a| color(:underline, a[0]) + a[1...] }.join("/")
      loop do
        read = prompt_freeform "#{color_last_line(QUESTION_COLOR, question)} [#{colored_answers}]", color: :none
        return read if answers.include?(read)
        if (a = answers.map { |a| a[0] }.index(read))
          return answers[a]
        end
      end
    end

    def prompt_freeform(question, color: QUESTION_COLOR)
      warn color(color, question)
      STDIN.gets.strip
    end

    def color_last_line(color, text)
      lines = text.split("\n")
      lines[-1] = color(color, lines[-1])
      lines.join("\n")
    end

    def color(color, text)
      return text if color == :none
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
