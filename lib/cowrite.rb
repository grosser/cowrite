# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

class Cowrite
  def initialize(url:, api_key:, model:)
    @url = url
    @api_key = api_key
    @model = model
  end

  def files(prompt)
    # TODO: ask llm which folders to search when >1k files
    files = `git ls-files`
    abort files unless $?.success?

    prompt = <<~MSG
      Your task is to find a subset of files from a given list of file names.
      Only reply with the subset of files, newline separated, nothing else.

      Given this list of files: #{files.split("\n").inspect}

      Which subset of files would be useful for this LLM prompt:
      ```
      #{prompt}
      ```
    MSG
    puts "prompt:#{prompt}" if ENV["DEBUG"]
    answer = send_to_openai(prompt)
    puts "answer:\n#{answer}" if ENV["DEBUG"]
    without_quotes(answer).split("\n").map(&:strip) # llms like to add extra spaces
  end

  def diff(file, prompt)
    # - tried "patch format" but that is often invalid
    # - tied "full fixed content" but that is always missing the fix
    # - need "ONLY" or it adds comments
    prompt = <<~MSG
      Solve this prompt:
      ```
      #{prompt}
      ```

      By changing the content of the file #{file}:
      ```
      #{File.read file}
      ```

      Reply with ONLY the change in diff format.
    MSG
    puts "prompt:#{prompt}" if ENV["DEBUG"]
    answer = send_to_openai(prompt)
    puts "answer:\n#{answer}" if ENV["DEBUG"]
    without_quotes(answer)
  end

  private

  # remove ```foo<content>``` wrapping
  def without_quotes(answer)
    answer.strip.sub(/\A```\S*\n(.*)```\z/m, "\\1")
  end

  # def lines_from_file(file_path, line_number)
  #   start_line = [line_number - @context, 1].max
  #   end_line = line_number + @context
  #
  #   lines = File.read(file_path).split("\n", -1)
  #   context = lines.each_with_index.map { |l, i| "line #{(i + 1).to_s.rjust(5, " ")}:#{l}" }
  #   [lines[line_number - 1], context[start_line - 1..end_line - 1]]
  # end
  #
  # def replace_line_in_file(file_path, line_number, new_line)
  #   lines = File.read(file_path).split("\n", -1)
  #   lines[line_number - 1] = new_line
  #   File.write(file_path, lines.join("\n"))
  # end
  #
  # def append_line_to_file(path, answer)
  #   File.open(path, "a") do |f|
  #     f.puts(answer)
  #   end
  # end
  #
  # def remove_line_in_file(path, line_number)
  #   lines = File.read(path).split("\n", -1)
  #   lines.delete_at(line_number - 1)
  #   File.write(path, lines.join("\n"))
  # end

  def send_to_openai(prompt)
    uri = URI.parse("#{@url}/v1/chat/completions")
    request = Net::HTTP::Post.new(uri)
    request.content_type = "application/json"
    request["Authorization"] = "Bearer #{@api_key}"

    request.body = JSON.dump(
      {
        model: @model,
        messages: [{ role: "user", content: prompt }],
        max_completion_tokens: 10_000,
        temperature: 0.3
      }
    )

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end
    raise "Invalid http response #{response.code}:\n#{response.body}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)["choices"][0]["message"]["content"]
  end
end
