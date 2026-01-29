#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo script for SemanticCache
#
# Usage:
#   OPENAI_API_KEY=sk-... ruby examples/demo.rb
#
# Or for a simulated demo (no API key needed):
#   ruby examples/demo.rb --simulate

require_relative "../lib/semantic_cache"

SIMULATE = ARGV.include?("--simulate")

puts "=" * 60
puts "  SemanticCache Demo"
puts "  Semantic caching for LLM API calls"
puts "=" * 60
puts

if SIMULATE
  puts "[Simulation mode — no API calls will be made]\n\n"

  # Create a cache with a fake embedding generator for simulation
  cache = SemanticCache.new(similarity_threshold: 0.85)

  # Override embedding to use a simple hash-based fake
  # In real use, embeddings come from OpenAI's API
  fake_embeddings = {}
  base_vector = Array.new(16) { rand(-1.0..1.0) }

  cache.instance_variable_get(:@embedding).define_singleton_method(:generate) do |text|
    # Generate a deterministic "embedding" — similar texts get similar vectors
    normalized = text.downcase.gsub(/[^a-z ]/, "").split.sort.join(" ")
    fake_embeddings[normalized] ||= base_vector.map { |v| v + rand(-0.05..0.05) }
    fake_embeddings[normalized]
  end
else
  unless ENV["OPENAI_API_KEY"]
    puts "Error: OPENAI_API_KEY environment variable is required."
    puts "Run with --simulate for a demo without API calls."
    exit 1
  end

  SemanticCache.configure do |c|
    c.openai_api_key = ENV["OPENAI_API_KEY"]
  end

  cache = SemanticCache.new
end

puts "--- Basic Caching ---\n\n"

queries = [
  "What's the capital of France?",
  "What is France's capital?",
  "Tell me the capital city of France",
  "France capital?",
  "What is the biggest planet in our solar system?",
  "Which planet is the largest in the solar system?"
]

queries.each.with_index(1) do |query, i|
  puts "Query #{i}: #{query}"

  result = cache.fetch(query, model: "gpt-4o") do
    sleep(0.3) if SIMULATE # Simulate API latency
    case query
    when /france/i then "Paris is the capital of France."
    when /planet/i then "Jupiter is the largest planet in our solar system."
    else "I don't know the answer to that."
    end
  end

  stats = cache.current_stats
  status = stats[:last_hit] ? "CACHE HIT!" : "Cache miss (API call)"
  puts "  -> #{status}"
  puts "  Response: #{result}"
  puts "  Hit rate: #{stats[:hit_rate]}% | Savings: #{stats[:savings]}"
  puts
end

puts "\n--- Tag-based Invalidation ---\n\n"

cache2 = SIMULATE ? cache : SemanticCache.new
if SIMULATE
  cache2.clear
end

puts "Caching with tags..."
cache2.fetch("Latest Ruby version?", tags: [:ruby, :versions], model: "gpt-4o") do
  "Ruby 3.3.0 is the latest stable release."
end
puts "  Cached 'Latest Ruby version?' with tags [:ruby, :versions]"

cache2.fetch("Best Ruby framework?", tags: [:ruby, :frameworks], model: "gpt-4o") do
  "Rails is the most popular Ruby web framework."
end
puts "  Cached 'Best Ruby framework?' with tags [:ruby, :frameworks]"

puts "  Cache size: #{cache2.size}"
puts "  Invalidating tag :versions..."
cache2.invalidate(tags: [:versions])
puts "  Cache size after invalidation: #{cache2.size}"
puts

puts "\n--- Stats Report ---\n\n"
puts cache.detailed_stats
puts
puts cache.savings_report
puts
puts "=" * 60
puts "  Demo complete!"
puts "=" * 60
