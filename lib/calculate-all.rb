require "active_support"
require "calculate-all/version"

module CalculateAll
  # Calculates multiple aggregate values on a scope in one request, similarly to #calculate
  def calculate_all(*function_shortcuts, **functions, &block)
    # If only one aggregate is given without explicit naming,
    # return row(s) directly without wrapping in Hash
    if function_shortcuts.size == 1 && functions.size == 0
      return_plain_values = true
    end

    functions = function_shortcuts.map { |name| [name, name] }.to_h.merge(functions)
    # Convert shortcuts to actual SQL
    functions.transform_values! do |shortcut|
      CalculateAll::Helpers.decode_function_shortcut(shortcut, group_values)
    end

    raise ArgumentError, "provide at least one function to calculate" if functions.empty?

    # Some older active_record versions do not allow for repeating expressions in pluck list,
    # and functions could contain group values.
    columns = (group_values + functions.values).uniq
    value_mapping = functions.transform_values { |column| columns.index(column) }
    columns.map! { |column| column.is_a?(String) ? Arel.sql(column) : column }

    results = {}
    pluck(*columns).each do |row|
      # If pluck called with with a single argument
      # it will return an array of sclars instead of array of arrays
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
      # freeze it to prevent surprize modifications across multiple rows in the calling code.
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
