require 'test_helper'

class CalculateAllPostgresqlTest < Minitest::Test

  def db_credentials
    {adapter: "postgresql", database: "calculate_all_test"}
  end

  def setup
    super unless defined? @@connected
    @@connected = true
  end

  include CalculateAllCommon

  def test_returns_array_on_array_aggregate
    create_orders
    expected = %W[USD RUB USD USD RUB]
    assert_equal expected, Order.calculate_all('ARRAY_AGG(currency ORDER BY id)')
  end

  def test_returns_array_on_grouped_array_aggregate
    create_orders
    expected = {
      "card"=>["USD", "RUB"],
      "cash"=>["USD", "USD", "RUB"],
    }
    assert_equal expected, Order.group(:kind).calculate_all('ARRAY_AGG(currency ORDER BY id)')
  end

end
