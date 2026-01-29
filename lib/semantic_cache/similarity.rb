# frozen_string_literal: true

module SemanticCache
  module Similarity
    module_function

    # Compute cosine similarity between two vectors.
    # Returns a Float between -1.0 and 1.0.
    def cosine(vec_a, vec_b)
      return 0.0 if vec_a.empty? || vec_b.empty?
      raise ArgumentError, "Vectors must be the same length" unless vec_a.length == vec_b.length

      dot_product = 0.0
      magnitude_a = 0.0
      magnitude_b = 0.0

      vec_a.length.times do |i|
        a = vec_a[i]
        b = vec_b[i]
        dot_product += a * b
        magnitude_a += a * a
        magnitude_b += b * b
      end

      denominator = Math.sqrt(magnitude_a) * Math.sqrt(magnitude_b)
      return 0.0 if denominator.zero?

      dot_product / denominator
    end
  end
end
