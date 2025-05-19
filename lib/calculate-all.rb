require "active_support"
require "calculate-all/version"

module CalculateAll
  # Calculates multiple aggregate values on a scope in one request, similarly to #calculate
  def calculate_all(*expression_shortcuts, **named_expressions, &block)
    # If only one aggregate is given as a string or Arel.sql without explicit naming,
    # return row(s) directly without wrapping in Hash
    if expression_shortcuts.size == 1 && expression_shortcuts.first.is_a?(String) &&
        named_expressions.size == 0
      return_plain_values = true
    end

    named_expressions = expression_shortcuts.map { |name| [name, name] }.to_h.merge(named_expressions)

    named_expressions.transform_values! do |shortcut|
      Helpers.decode_expression_shortcut(shortcut, group_values)
    end

    raise ArgumentError, "provide at least one expression to calculate" if named_expressions.empty?

    # Some older active_record versions do not allow for repeating expressions in pluck list,
    # and named expressions could contain group values.
    columns = (group_values + named_expressions.values).uniq
    value_mapping = named_expressions.transform_values { |column| columns.index(column) }
    columns.map! { |column| column.is_a?(String) ? Arel.sql(column) : column }

    results = {}
    pluck(*columns).each do |row|
      # If pluck called with a single argument
      # it will return an array of scalars instead of array of arrays
      row = [row] if columns.size == 1

      key = if group_values.size == 0
        :ALL
      elsif group_values.size == 1
        # If only one group is provided, the resulting key is just a scalar value
        row.first
      else
        # if multiple groups, the key will be an array.
        row.first(group_values.size)
      end

      value = value_mapping.transform_values { |index| row[index] }

      value = value.values.last if return_plain_values

      results[key] = value
    end

    # Additional groupdate magic of filling empty periods with defaults
    if defined?(Groupdate.process_result)
      # Since that hash is the same instance for every backfilled row, at least
      # freeze it to prevent surprise modifications across multiple rows in the calling code.
      default_value = return_plain_values ? nil : {}.freeze
      results = Groupdate.process_result(self, results, default_value: default_value)
    end

    if block
      results.transform_values! do |value|
        return_plain_values ? block.call(value) : block.call(**value)
      end
    end

    # Return unwrapped hash directly for scope without any .group()
    if group_values.empty?
      results[:ALL]
    else
      results
    end
  end

  # module just to not pollute namespace
  module Helpers
    module_function

    # Convert shortcuts like :count_distinct_id to SQL aggregate functions like 'COUNT(DISTINCT ID)'
    # If shortcut is actually one of the grouping expressions, just return it as-is.
    def decode_expression_shortcut(shortcut, group_values = [])
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
        raise ArgumentError, "Can't recognize expression shortcut #{shortcut}"
      end
    end
  end

  module Querying
    # @see CalculateAll#calculate_all
    def calculate_all(*args, **kwargs, &block)
      all.calculate_all(*args, **kwargs, &block)
    end
  end
end

ActiveSupport.on_load(:active_record) do
  # Make the calculate_all method available for all ActiveRecord::Relations instances
  ActiveRecord::Relation.include CalculateAll

  # Make the calculate_all method available for all ActiveRecord::Base classes
  # You can for example call Orders.calculate_all(:count, :sum_cents)
  ActiveRecord::Base.extend CalculateAll::Querying

  # A hack for groupdate 3.0 since it checks if the calculate_all method is defined
  # on the ActiveRecord::Calculations module. It is never called but it is just
  # needed for the check.
  ActiveRecord::Calculations.include CalculateAll::Querying
end
