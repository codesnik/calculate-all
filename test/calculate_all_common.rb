module CalculateAllCommon

  class ::Order < ActiveRecord::Base
  end

  def setup
    ActiveRecord::Migration.verbose = false
    ActiveRecord::Base.establish_connection db_credentials
    ActiveRecord::Migration.create_table :orders, force: true do |t|
      t.string :kind
      t.string :currency
      t.integer :cents
      t.timestamp :created_at
    end
    ::Order.establish_connection db_credentials
  end

  def teardown
    Order.delete_all
  end

  def test_that_it_has_a_version_number
    refute_nil ::CalculateAll::VERSION
  end

  def test_no_args
    assert_raises ArgumentError do
      Order.all.calculate_all
    end
  end

  def test_model_and_no_data
    assert_nil(Order.calculate_all(:cents_sum))
  end

  def test_scope_and_single_expression_no_data
    assert_nil(Order.all.calculate_all(:cents_sum))
  end

  def test_one_group_and_no_data
    assert_equal({}, Order.group(:kind).calculate_all(:cents_sum))
  end

  def test_many_groups_and_no_data
    assert_equal({}, Order.group(:kind).group(:currency).calculate_all(:cents_sum))
  end

  def test_one_group_many_expressions
    create_orders
    expected = {
      'RUB' => { count: 2, cents_sum: 700 },
      'USD' => { count: 3, cents_sum: 800 }
    }
    assert_equal(expected, Order.group(:currency).calculate_all(:count, :cents_sum))
  end

  def test_many_groups_many_expressions
    create_orders
    expected = {
      ['card', 'USD'] => { cents_min: 100, cents_max: 100 },
      ['cash', 'USD'] => { cents_min: 300, cents_max: 400 },
      ['card', 'RUB'] => { cents_min: 200, cents_max: 200 },
      ['cash', 'RUB'] => { cents_min: 500, cents_max: 500 }
    }
    assert_equal(expected, Order.group(:kind).group(:currency).calculate_all(:cents_min, :cents_max))
  end

  def test_expression_aliases
    create_orders
    assert_equal({foo: 2}, Order.calculate_all(foo: 'count(distinct currency)'))
  end

  def test_returns_only_value_on_no_groups_one_string_expression
    create_orders
    assert_equal(400, Order.calculate_all('MAX(cents) - MIN(cents)'))
  end

  def test_returns_only_values_on_one_group_one_string_expression
    create_orders
    expected = {
      'RUB' => 300,
      'USD' => 300,
    }
    assert_equal(expected, Order.group(:currency).calculate_all('MAX(cents) - MIN(cents)'))
  end

  def test_returns_only_value_on_no_groups_and_one_expression
    create_orders
    assert_equal 2, Order.calculate_all(:count_distinct_currency)
  end

  def test_returns_only_values_on_one_group_and_one_expression
    create_orders
    expected = {
      'cash' => 3,
      'card' => 2,
    }
    assert_equal expected, Order.group(:kind).calculate_all(:count)
  end

  def test_groupdate_compatibility
    require 'groupdate'
    create_orders
    expected = {
      ['card', Date.new(2014,1,1)] => { count: 1, sum_cents: 100 },
      ['card', Date.new(2015,1,1)] => { count: 1, sum_cents: 200 },
      ['cash', Date.new(2014,1,1)] => { count: 1, sum_cents: 300 },
      ['cash', Date.new(2015,1,1)] => { count: 2, sum_cents: 900 }
    }
    assert_equal expected, Order.group(:kind).group_by_year(:created_at).calculate_all(:count, :sum_cents)
  end

  def test_value_wrapping_one_expression_and_no_groups
    create_orders
    assert_equal '5 orders', Order.calculate_all(:count) { |count| "#{count} orders" }
  end

  def test_value_wrapping_for_one_expression
    create_orders
    expected = {
      'RUB' => '2 orders',
      'USD' => '3 orders',
    }
    assert_equal expected, Order.group(:currency).calculate_all(:count) { |count|
      "#{count} orders"
    }
  end

  def test_value_wrapping_for_several_expressions
    create_orders
    expected = {
      'RUB' => '2 orders, 350 cents average',
      'USD' => '3 orders, 266 cents average',
    }
    assert_equal expected, Order.group(:currency).calculate_all(:count, :avg_cents) { |count:, avg_cents:|
      "#{count} orders, #{avg_cents.to_i} cents average"
    }
  end

  def create_orders
    Order.create! [
      { kind: 'card', currency: 'USD', cents: 100, created_at: Time.utc(2014,1,3) },
      { kind: 'card', currency: 'RUB', cents: 200, created_at: Time.utc(2015,1,5) },
      { kind: 'cash', currency: 'USD', cents: 300, created_at: Time.utc(2014,1,10) },
      { kind: 'cash', currency: 'USD', cents: 400, created_at: Time.utc(2015,5,10) },
      { kind: 'cash', currency: 'RUB', cents: 500, created_at: Time.utc(2015,10,10) },
    ]
  end
end
