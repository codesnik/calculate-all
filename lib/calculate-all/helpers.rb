module CalculateAll
  module Helpers
    module_function

    # Convert shortcuts like :count_distinct_id to SQL aggregate functions like 'COUNT(DISTINCT ID)'
    # If shortcut is actually one of the grouping expressions, just return it as-is.
    def decode_function_shortcut(shortcut, group_values = [])
      case shortcut
      when String
        shortcut
      when *group_values
        shortcut
      when :count
        "COUNT(*)"
      when /^(\w+)_distinct_count$/, /^count_distinct_(\w+)$/
        "COUNT(DISTINCT #{$1})"
      when /^(\w+)_(count|sum|max|min|avg)$/
        "#{$2.upcase}(#{$1})"
      when /^(count|sum|max|min|avg)_(\w+)$/
        "#{$1.upcase}(#{$2})"
      when /^(\w+)_average$/, /^average_(\w+)$/
        "AVG(#{$1})"
      when /^(\w+)_maximum$/, /^maximum_(\w+)$/
        "MAX(#{$1})"
      when /^(\w+)_minimum$/, /^minimum_(\w+)$/
        "MIN(#{$1})"
      else
        raise ArgumentError, "Can't recognize function shortcut #{key}"
      end
    end
  end
end
