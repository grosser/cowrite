# frozen_string_literal: true
require_relative "test_helper"

SingleCov.covered! uncovered: 12

describe Cowrite do
  let(:cowrite) { Cowrite.new(url: "https://api.openai.com", api_key: "x", model: "x") }

  it "has a VERSION" do
    Cowrite::VERSION.must_match /^[.\da-z]+$/
  end

  describe "#files" do
    def call
      Tempfile.create("test") do |f|
        File.write(f, "a\nb\nc")
        `true` # fill $?
        cowrite.stubs(:`).returns("f")
        cowrite.stubs(:send_to_openai).returns("x")
        cowrite.files("hi")
      end
    end

    it "calls" do
      call.must_equal ["x"]
    end
  end

  describe "#send_to_openai" do
    def call
      cowrite.send(:send_to_openai, "hi")
    end

    it "sends" do
      stub_request(:post, "https://api.openai.com/v1/chat/completions")
        .with(headers: { 'Authorization' => 'Bearer x' })
        .to_return(body: { choices: [{ message: { content: "ho" } }] }.to_json)
      call.must_equal "ho"
    end

    it "fails on error" do
      stub_request(:post, "https://api.openai.com/v1/chat/completions")
        .to_return(status: 400)
      e = assert_raises(RuntimeError) { call }
      e.message.must_include "Invalid http response 400"
    end
  end

  describe "#generate_diff" do
    def call(...)
      cowrite.send(:generate_diff, ...)
    end

    it "builds a diff" do
      original = "a\nb\nc\nd"
      diff = call(original, "c", from: 2, to: 3)

      # diff is good
      diff.must_equal <<~DIFF
        2d1
        < b
      DIFF

      # diff can be applied (see cli.rb)
      Tempfile.create "a" do |a|
        Tempfile.create "b" do |b|
          a.write original
          a.close
          b.write diff
          b.close
          out = `patch --posix #{a.path} < #{b.path}`
          $?.success?.must_equal true, out
          File.read(a.path).must_equal "a\nc\nd"
        end
      end
    end

    it "fails on empty diff" do
      e = assert_raises(RuntimeError) { call "a", "a", from: 1, to: 1 }
      e.message.must_include "No diff"
    end

    it "fails when diff fails" do
      `fooo 2>&1` # fill $? with exit 127
      cowrite.expects(:`)
      e = assert_raises(RuntimeError) { call "a", "a", from: 1, to: 1 }
      e.message.must_include "diff failed"
    end
  end
end
