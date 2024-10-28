# frozen_string_literal: true

# test that need api key set and might not be deterministic

require_relative "test_helper"

describe "integration" do
  def cowrite(*argv)
    out = `echo | DEBUG=1 #{Bundler.root}/bin/cowrite #{argv.shelljoin} 2>&1`
    assert $?.success?, out
    out
  end

  it "can fix bug in a file" do
    Tempfile.create("test.rb") do |f|
      File.write f.path, <<~RUBY
        if a = 1
          puts a
        end
      RUBY
      cowrite("wrap conditional assignments in ()", "--", f.path)
      File.read(f.path).must_equal <<~RUBY
        if (a = 1)
          puts a
        end
      RUBY
    end
  end

  it "can run in parallel" do
    Tempfile.create("test.rb") do |f|
      File.write f.path, <<~RUBY
        if a = 1
          puts a
        end
      RUBY
      cowrite("wrap conditional assignments in ()", "--parallel=3", "--", f.path)
      File.read(f.path).must_equal <<~RUBY
        if (a = 1)
          puts a
        end
      RUBY
    end
  end

  it "can change multiple things in 1 file without getting lines confused" do
    Tempfile.create("test.rb") do |f|
      File.write f.path, "1\n" + ("2\n" * 10) + "1\n"
      cowrite("change every line with a 1 to 5 lines with a single 3", "--", f.path)
      File.read(f.path).must_equal ("3\n" * 5) + ("2\n" * 10) + ("3\n" * 5)
    end
  end

  it "can create a file" do
    Dir.mktmpdir do |dir|
      Dir.chdir dir do
        `git init` # make `git ls-files` not crash
        File.write "bar.txt", "nope"
        cowrite "write foo to foo.txt"
        File.read("#{dir}/foo.txt").must_equal "foo"
      end
    end
  end
end
