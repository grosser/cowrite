# frozen_string_literal: true
require_relative "../test_helper"
require "cowrite/cli"

SingleCov.covered! uncovered: 65

describe Cowrite::CLI do
  let(:cli) { Cowrite::CLI.new }

  describe "#color_last_line" do
    def call(...)
      cli.send(:color_last_line, ...)
    end

    it "colors" do
      call(:blue, "a\nb\nc").must_equal "a\nb\n\e[34mc\e[0m"
    end
  end

  describe "#color_diff" do
    def call(...)
      cli.send(:color_diff, ...)
    end

    it "does not color header" do
      call("---\n+++").must_equal "---\n+++"
    end

    it "colors diff" do
      call("-a\n+b\nc").must_equal "\e[101m-a\e[0m\n\e[102m+b\e[0m\nc"
    end
  end

  describe "#modify_lines" do
    def call(...)
      cli.send(:modify_lines, ...)
    end

    it "noops" do
      call("a\n\nb") { |l| l }.must_equal "a\n\nb"
    end
  end

  describe "#prompt_freeform" do
    def call(...)
      cli.send(:prompt_freeform, ...)
    end

    it "accepts any answer" do
      $stdin.expects(:gets).returns "x"
      capture_stderr { call("wut").must_equal "x" }
    end
  end

  describe "#prompt" do
    def call(...)
      cli.send(:prompt, ...)
    end

    it "accepts allowed answer" do
      $stdin.expects(:gets).returns "yes"
      capture_stderr { call("wut", ["yes", "no"]).must_equal "yes" }
    end

    it "accepts short answer" do
      $stdin.expects(:gets).returns "yes"
      capture_stderr { call("wut", ["yes", "no"]).must_equal "yes" }
    end

    it "does not accept wrong answer" do
      $stdin.expects(:gets).times(2).returns "wut", "yes"
      capture_stderr { call("wut", ["yes", "no"]).must_equal "yes" }
    end

    it "accepts enter for yes" do
      $stdin.expects(:gets).returns ""
      capture_stderr { call("wut", ["yes", "no"]).must_equal "yes" }
    end

    it "does not accept enter for others" do
      $stdin.expects(:gets).times(2).returns "", "no"
      capture_stderr { call("wut", ["wut", "no"]).must_equal "no" }
    end

    it "ignores spaces" do
      $stdin.expects(:gets).returns "yes "
      capture_stderr { call("wut", ["yes", "no"]).must_equal "yes" }
    end
  end

  describe "#expand_file_globs" do
    def call(...)
      cli.send(:expand_file_globs, ...)
    end

    it "keeps existing file" do
      call(["Gemfile"]).must_equal ["Gemfile"]
    end

    it "expands globs" do
      call(["Gemfil*"]).must_equal ["Gemfile", "Gemfile.lock"]
    end

    it "keeps files that are to be created" do
      call(["nomatch"]).must_equal ["nomatch"]
    end
  end
end
