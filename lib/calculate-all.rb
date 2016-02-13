require "calculate-all/version"
require "active_record"

module CalculateAll
  def calculate_all(*function_aliases, **functions, &block)
    if function_aliases.size == 1 && functions == {}
      return_plain_values = true
    end
    functions.merge!(
      CalculateAll::Helpers.decode_function_aliases(function_aliases)
    )
    if functions == {}
      raise ArgumentError, "provide at least one function to calculate"
    end
    # groupdate compatibility
    group_values = self.group_values
    if !group_values.is_a?(Array) && group_values.respond_to?(:relation)
      group_values = group_values.relation
    end
    if functions.size == 1 && group_values.size == 0
      plain_rows = true
    end

    results = {}

    pluck(*group_values, *functions.values).each do |row|
      row = [row] if plain_rows
      if return_plain_values
        value = row.last
      else
        value = functions.keys.zip(row.last(functions.size)).to_h
      end

      value = block.call(value) if block

      # Return unwrapped hash directly for scope without any .group()
      return value if group_values.empty?

      if group_values.size == 1
        key = row.first
      else
        key = row.first(group_values.size)
      end
      results[key] = value
    end

    results
  end

  module Helpers
    module_function
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
  module Querying
    delegate :calculate_all, to: :all
  end
end

# should be:
#   ActiveRecord::Relation.include CalculateAll
# including in module instead, for groupdate compatibility
ActiveRecord::Calculations.include CalculateAll

ActiveRecord::Base.extend CalculateAll::Querying
