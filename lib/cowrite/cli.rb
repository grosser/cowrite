# frozen_string_literal: true

require "shellwords"
require "parallel"
require "tempfile"
require "optparse"

class Cowrite
  class CLI
    QUESTION_COLOR = :blue

    def initialize
      super

      # get config first so we fail fast
      api_key = ENV.fetch("COWRITE_API_KEY")
      url = ENV.fetch("COWRITE_URL", "https://api.openai.com")
      model = ENV.fetch("MODEL", "gpt-4o")
      @cowrite = Cowrite.new(url:, api_key:, model:)
    end

    def run(argv)
      prompt, files, options = parse_argv(argv)

      files = find_files prompt if files.empty?

      if (parallel = options[:parallel])
        prompt_for_each_file_in_parallel prompt, files, parallel
      else
        prompt_with_all_files_in_context prompt, files
      end
    end

    private

    # send all files at once to have a bigger context
    # TODO: might break if context gets too big
    def prompt_with_all_files_in_context(prompt, files)
      diffs = @cowrite.diffs(prompt, files)
      diffs.each_with_index do |(file, diff), i|
        last = (i + 1 == diffs.size)
        prompt_to_apply_diff file, diff, last:
      end
    end

    # run each file in parallel (faster) or all at once ?
    # prompting on main thread so we don't get parallel prompts
    def prompt_for_each_file_in_parallel(prompt, files, parallel)
      finish = lambda do |file, i, diffs|
        diffs.each_with_index do |(_, diff), j|
          last = (i + 1 == files.size && j + 1 == diffs.size)
          prompt_to_apply_diff file, diff, last:
        end
      end

      # produce diffs in parallel since multiple files will be slow and can confuse the model
      Parallel.each files, finish:, threads: parallel, progress: true do |file, _i|
        @cowrite.diffs prompt, [file]
      end
    end

    def prompt_to_apply_diff(file, diff, last:)
      # ask user if diff is fine (TODO: add a "no" option and re-prompt somehow)
      prompt "Diff for #{file}:\n#{color_diff(diff)}Apply diff to #{file}?", ["yes"]
      return if apply_diff(file, diff)

      # ask user to continue if diff failed to apply (to give time for manual fixes or abort)
      prompt "Continue ?", ["yes"] unless last
    end

    # apply diff (force sus changes, do not make backups)
    def apply_diff(file, diff)
      with_content_in_file(diff) do |path|
        ensure_file_exists(file)
        cmd = "patch --posix #{file} < #{path}"
        out = `#{cmd}`
        return true if $?.success?

        # give the user a chance to copy the tempfile or modify it
        warn "Patch failed:\n#{cmd}\n#{out}"
        false
      end
    end

    def ensure_file_exists(file)
      return if File.exist?(file)
      FileUtils.mkdir_p(File.dirname(file))
      File.write file, ""
    end

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
      warn "Files #{missing} do not exist, assuming they will be created" if missing.any?
      chosen
    end

    # prompt user with questions and answers until they pick one of them
    # - supports replying with the first letter of the answer
    # - supports enter for yes
    # - when not interactive assume yes
    def prompt(question, answers)
      if $stdin.tty?
        colored_answers = answers.map { |a| color(:underline, a[0]) + a[1...] }.join("/")
        loop do
          read = prompt_freeform "#{color_last_line(QUESTION_COLOR, question)} [#{colored_answers}]", color: :none
          read = "yes" if read == "" && answers.include?("yes")
          return read if answers.include?(read)
          if (ai = answers.map { |a| a[0] }.index(read))
            return answers[ai]
          end
        end
      else
        return "yes" if answers.include?("yes")
        abort "need answer but was not in interactive mode"
      end
    end

    def prompt_freeform(question, color: QUESTION_COLOR)
      warn color(color, question)
      $stdin.gets.strip
    end

    def color_last_line(color, text)
      modify_lines(text) { |l, i, size| i + 1 == size ? color(color, l) : l }
    end

    # color lines with +/- but not the header with ---/+++
    def color_diff(diff)
      modify_lines(diff) do |l, _, _|
        if l =~ /^-[^-]/
          color(:bg_light_red, l)
        elsif l =~ /^\+[^+]/
          color(:bg_light_green, l)
        else
          l
        end
      end
    end

    def modify_lines(text)
      lines = text.split("\n", -1)
      size = lines.size
      lines = lines.each_with_index.map { |l, i| yield l, i, size }
      lines.join("\n")
    end

    def color(color, text)
      return text if color == :none
      code =
        case color
        when :underline then 4
        when :blue then 34
        when :bg_light_red then 101
        when :bg_light_green then 102
        else raise ArgumentError
        end
      "\e[#{code}m#{text}\e[0m"
    end

    def remove_shell_colors(string)
      string.gsub(/\e\[(\d+)(;\d+)*m/, "")
    end

    def parse_argv(argv)
      # allow passing files after --
      argv, files =
        if (dash_index = argv.index("--"))
          [argv[0...dash_index], argv[dash_index + 1..]]
        else
          [argv, []]
        end

      options = {}
      OptionParser.new do |opts|
        opts.banner = <<-BANNER.gsub(/^ {10}/, "")
          WWTD: Travis simulator - faster + no more waiting for build emails

          Usage:
              wwtd

          Options:
        BANNER
        opts.on("-p", "--parallel [COUNT]", Integer, "Run each file on its own in parallel") do |c|
          options[:parallel] = c
        end
        opts.on("-h", "--help", "Show this.") do
          puts opts
          exit
        end
        opts.on("-v", "--version", "Show Version") do
          puts WWTD::VERSION
          exit
        end
      end.parse!(argv)

      abort "Use only first argument for prompt" if argv.size != 1
      prompt = argv[0]
      [prompt, expand_file_globs(files), options]
    end

    def expand_file_globs(files)
      files.flat_map do |f|
        found = Dir[f]
        found.any? ? found : f
      end
    end
  end
end
