module CalculateAll
  module Helpers
    module_function

    # Method to convert function aliases like :count to SQL commands like 'COUNT(*)'
    def decode_function_aliases(aliases)
      aliases.map do |key|
        function =
          case key
          when String
            key
          when :count
            "COUNT(*)"
          when /^(.*)_distinct_count$/, /^count_distinct_(.*)$/
            "COUNT(DISTINCT #{$1})"
          when /^(.*)_(count|sum|max|min|avg)$/
            "#{$2.upcase}(#{$1})"
          when /^(count|sum|max|min|avg)_(.*)$$/
            "#{$1.upcase}(#{$2})"
          when /^(.*)_average$/, /^average_(.*)$/
            "AVG(#{$1})"
          when /^(.*)_maximum$/, /^maximum_(.*)$/
            "MAX(#{$1})"
          when /^(.*)_minimum$/, /^minimum_(.*)$/
            "MIN(#{$1})"
          else
            raise ArgumentError, "Can't recognize function alias #{key}"
          end
        [key, function]
      end.to_h
    end
  end
end
