# frozen_string_literal: true

require "monitor"

module SemanticCache
  class Stats
    include MonitorMixin

    attr_reader :hits, :misses, :total_savings, :last_event

    def initialize
      super() # Initialize MonitorMixin
      @hits = 0
      @misses = 0
      @total_savings = 0.0
      @last_event = nil
      @response_times = []
      @cached_response_times = []
    end

    def record_hit(saved_cost: 0.0, response_time: nil)
      synchronize do
        @hits += 1
        @total_savings += saved_cost
        @last_event = :hit
        @cached_response_times << response_time if response_time
      end
    end

    def record_miss(response_time: nil)
      synchronize do
        @misses += 1
        @last_event = :miss
        @response_times << response_time if response_time
      end
    end

    def total_queries
      synchronize { @hits + @misses }
    end

    def hit_rate
      synchronize do
        total = @hits + @misses
        return 0.0 if total.zero?

        (@hits.to_f / total * 100).round(1)
      end
    end

    def avg_response_time
      synchronize do
        return 0.0 if @response_times.empty?

        (@response_times.sum / @response_times.length).round(2)
      end
    end

    def avg_cached_response_time
      synchronize do
        return 0.0 if @cached_response_times.empty?

        (@cached_response_times.sum / @cached_response_times.length).round(2)
      end
    end

    def to_h
      synchronize do
        {
          hits: @hits,
          misses: @misses,
          total_queries: @hits + @misses,
          hit_rate: hit_rate,
          savings: format("$%.2f", @total_savings),
          total_savings: @total_savings,
          last_hit: @last_event == :hit,
          avg_response_time_ms: avg_response_time,
          avg_cached_response_time_ms: avg_cached_response_time
        }
      end
    end

    def report
      synchronize do
        lines = []
        lines << "Total queries: #{@hits + @misses}"
        lines << "Cache hits: #{@hits}"
        lines << "Cache misses: #{@misses}"
        lines << "Hit rate: #{hit_rate}%"
        lines << "Total savings: #{format("$%.2f", @total_savings)}"
        lines << "Avg API response time: #{avg_response_time}ms" unless @response_times.empty?
        lines << "Avg cached response time: #{avg_cached_response_time}ms" unless @cached_response_times.empty?
        lines.join("\n")
      end
    end

    def reset!
      synchronize do
        @hits = 0
        @misses = 0
        @total_savings = 0.0
        @last_event = nil
        @response_times = []
        @cached_response_times = []
      end
    end
  end
end
