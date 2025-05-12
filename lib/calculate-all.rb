require "active_support"
require "calculate-all/version"

module CalculateAll
  # Calculates multiple aggregate values on a scope in one request, similarly to #calculate
  def calculate_all(*function_aliases, **functions, &block)
    # If only one aggregate is given without explicit naming,
    # return row(s) directly without wrapping in Hash
    if function_aliases.size == 1 && functions.size == 0
      return_plain_values = true
    end

    # Convert the function_aliases to actual SQL
    functions.merge!(CalculateAll::Helpers.decode_function_aliases(function_aliases))

    # Check if any functions are given
    if functions == {}
      raise ArgumentError, "provide at least one function to calculate"
    end

    columns = (group_values.map(&:to_s) + functions.values).map { |sql| Arel.sql(sql) }
    results = {}
    pluck(*columns).each do |row|
      # If pluck called without any groups and with a single argument,
      # it will return an array of simple results instead of array of arrays
      if functions.size == 1 && group_values.size == 0
        row = [row]
      end

      key = if group_values.size == 0
        :ALL
      elsif group_values.size == 1
        # If only one group is provided, the resulting key is just a scalar value
        row.shift
      else
        # if multiple groups, the key will be an array.
        row.shift(group_values.size)
      end

      value = if return_plain_values
        row.last
      else
        # it is possible to have more actual group values returned than group_values.size
        functions.keys.zip(row.last(functions.size)).to_h
      end

      results[key] = value
    end

    # Additional groupdate magic of filling empty periods with defaults
    if defined?(Groupdate.process_result)
      # Since that hash is the same instance for every backfilled raw, at least
      # freeze it to prevent surprize modifications in calling code.
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
end

ActiveSupport.on_load(:active_record) do
  require "calculate-all/helpers"
  require "calculate-all/querying"

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
