# frozen_string_literal: true

# test that need api key set and might not be deterministic

require_relative "test_helper"

describe "integration" do
  it "can fix bug in a file" do
    Tempfile.create("test.rb") do |f|
      File.write f.path, <<~RUBY
        if a = 1
          puts a
        end
      RUBY
      assert system("echo | DEBUG=1 bin/cowrite 'wrap conditional assignments in ()' -- #{f.path} 2>&1 >/dev/null")
      File.read(f.path).must_equal <<~RUBY
        if (a = 1)
          puts a
        end
      RUBY
    end
  end
end
