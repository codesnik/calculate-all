require 'active_support'
require 'active_record'
require 'calculate-all/version'
require 'calculate-all/helpers'
require 'calculate-all/querying'

module CalculateAll
  # Method to aggregate function results in one request
  def calculate_all(*function_aliases, **functions, &block)

    # If only one function_alias is given, the result can be just a single value
    # So return [{ cash: 3 }] instead of [{ cash: { count: 3 }}]
    if function_aliases.size == 1 && functions == {}
      return_plain_values = true
    end

    # Convert the function_aliases to actual SQL
    functions.merge!(
      CalculateAll::Helpers.decode_function_aliases(function_aliases)
    )

    # Check if any functions are given
    if functions == {}
      raise ArgumentError, 'provide at least one function to calculate'
    end

    # If function is called without a group, the pluck method will still return
    # an array but it is an array with the final results instead of each group
    # The plain_rows boolean states how the results should be used
    if functions.size == 1 && group_values.size == 0
      plain_rows = true
    end

    # Final output hash
    results = {}

    columns = (group_values.map(&:to_s) + functions.values).map { |sql| Arel.sql(sql) }
    pluck(*columns).each do |row|

      # If no grouping, make sure it is still a results array
      row = [row] if plain_rows

      # If only one value, return a single value, else return a hash
      if return_plain_values
        value = row.last
        value = block.call(value) if block
      else
        value = functions.keys.zip(row.last(functions.size)).to_h
        value = block.call(**value) if block
      end

      # Return unwrapped hash directly for scope without any .group()
      return value if group_values.empty?

      # If only one group is provided, the resulting key is just the group name
      # if multiple group methods are provided, the key will be an array.
      if group_values.size == 1
        key = row.first
      else
        key = row.first(group_values.size)
      end

      # Set the value in the output array
      results[key] = value
    end

    # Convert timestamps in keys to dates if needed.
    if defined?(Groupdate.process_result)
      results = Groupdate.process_result(self, results)
    end

    # Return the output array
    results
  end
end

# Make the calculate_all method available for all ActiveRecord::Relations instances
ActiveRecord::Relation.include CalculateAll

# Make the calculate_all method available for all ActiveRecord::Base classes
# You can for example call Orders.calculate_all(:count, :sum_cents)
ActiveRecord::Base.extend CalculateAll::Querying

# A hack for groupdate since it checks if the calculate_all method is defined
# on the ActiveRecord::Calculations module. It is never called but it is just
# needed for the check.
ActiveRecord::Calculations.include CalculateAll::Querying
