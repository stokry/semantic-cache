# frozen_string_literal: true

require "monitor"

module SemanticCache
  module Stores
    # Thread-safe in-memory cache store.
    # Good for development, testing, and single-process apps.
    #
    # Options:
    #   max_size: Maximum number of entries to keep. When exceeded, the oldest
    #             entry (by created_at) is evicted. nil = unlimited.
    class Memory
      include MonitorMixin

      def initialize(max_size: nil, **_options)
        super()
        @data = {}
        @tags_index = Hash.new { |h, k| h[k] = Set.new }
        @max_size = max_size
      end

      # Store a cache entry. Evicts the oldest entry if max_size is reached.
      def write(key, entry)
        synchronize do
          evict_oldest! if @max_size && @data.size >= @max_size && !@data.key?(key)
          @data[key] = entry
          entry.tags.each { |tag| @tags_index[tag].add(key) }
        end
      end

      # Retrieve all non-expired entries.
      # Returns an Array of Entry objects.
      def entries
        synchronize do
          cleanup_expired!
          @data.values
        end
      end

      # Delete a specific entry by key.
      def delete(key)
        synchronize do
          entry = @data.delete(key)
          entry&.tags&.each { |tag| @tags_index[tag].delete(key) }
        end
      end

      # Delete all entries matching the given tags.
      def invalidate_by_tags(tags)
        synchronize do
          Array(tags).each do |tag|
            keys = @tags_index[tag].to_a
            keys.each { |key| @data.delete(key) }
            @tags_index.delete(tag)
          end
        end
      end

      # Delete all entries.
      def clear
        synchronize do
          @data.clear
          @tags_index.clear
        end
      end

      # Number of entries in the store.
      def size
        synchronize do
          cleanup_expired!
          @data.size
        end
      end

      private

      def cleanup_expired!
        expired_keys = @data.select { |_k, v| v.expired? }.keys
        expired_keys.each { |key| delete(key) }
      end

      # Evict the oldest entry (by created_at) to make room for a new one.
      def evict_oldest!
        oldest_key = @data.min_by { |_k, v| v.created_at }&.first
        delete(oldest_key) if oldest_key
      end
    end
  end
end
