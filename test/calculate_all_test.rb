require "test_helper"
require "groupdate"

class Department < ActiveRecord::Base
  has_many :orders
end

class Order < ActiveRecord::Base
  belongs_to :department
end

class CalculateAllTest < Minitest::Test
  def setup
    @@connected ||= begin
      if ENV["VERBOSE"]
        ActiveRecord::Base.logger = ActiveSupport::Logger.new($stdout)
      end
      ActiveRecord::Migration.verbose = false
      ActiveRecord::Base.establish_connection db_credentials
      ActiveRecord::Migration.create_table :departments, force: true do |t|
        t.string :name
      end
      ActiveRecord::Migration.create_table :orders, force: true do |t|
        t.string :kind
        t.string :currency
        t.integer :department_id
        t.integer :cents
        t.timestamp :created_at
      end
      true
    end
  end

  def teardown
    Order.delete_all
    Department.delete_all
  end

  def db_credentials
    if postgresql?
      {adapter: "postgresql", database: "calculate_all_test"}
    elsif mysql?
      {adapter: "mysql2", database: "calculate_all_test", username: "root"}
    elsif sqlite?
      {adapter: "sqlite3", database: ":memory:"}
    else
      raise "Set ENV['ADAPTER']"
    end
  end

  def postgresql?
    ENV["ADAPTER"] == "postgresql"
  end

  def mysql?
    ENV["ADAPTER"] == "mysql"
  end

  def sqlite?
    ENV["ADAPTER"] == "sqlite"
  end

  def old_groupdate?
    Gem::Version.new(Groupdate::VERSION) < Gem::Version.new("4.0.0")
  end

  def create_orders
    ActiveRecord::Base.transaction do
      Department.create! [
        {id: 1, name: "First"},
        {id: 2, name: "Second"}
      ]
      Order.create! [
        {department_id: 1, kind: "card", currency: "USD", cents: 100, created_at: Time.utc(2014, 1, 3)},
        {department_id: 2, kind: "card", currency: "RUB", cents: 200, created_at: Time.utc(2016, 1, 5)},
        {department_id: 2, kind: "cash", currency: "USD", cents: 300, created_at: Time.utc(2014, 1, 10)},
        {department_id: 1, kind: "cash", currency: "USD", cents: 400, created_at: Time.utc(2016, 5, 10)},
        {department_id: 2, kind: "cash", currency: "RUB", cents: 500, created_at: Time.utc(2016, 10, 10)}
      ]
    end
  end

  def test_it_has_a_version_number
    refute_nil ::CalculateAll::VERSION
  end

  def test_no_args
    assert_raises ArgumentError do
      Order.all.calculate_all
    end
  end

  def test_model_and_no_data
    assert_nil(Order.calculate_all("sum(cents)"))
  end

  def test_scope_and_single_expression_no_data
    assert_nil(Order.all.calculate_all("sum(cents)"))
  end

  def test_one_group_and_no_data
    assert_equal({}, Order.group(:kind).calculate_all(:cents_sum))
  end

  def test_many_groups_and_no_data
    assert_equal({}, Order.group(:kind).group(:currency).calculate_all(:cents_sum, :count))
  end

  def test_one_group_one_string_expression
    create_orders
    expected = {
      "RUB" => 700,
      "USD" => 800
    }
    assert_equal(expected, Order.group(:currency).calculate_all("sum(cents)"))
  end

  def test_one_group_one_expression
    create_orders
    expected = {
      "RUB" => {cents_sum: 700},
      "USD" => {cents_sum: 800}
    }
    assert_equal(expected, Order.group(:currency).calculate_all(:cents_sum))
  end

  def test_one_group_many_expressions
    create_orders
    expected = {
      "RUB" => {count: 2, cents_sum: 700},
      "USD" => {count: 3, cents_sum: 800}
    }
    assert_equal(expected, Order.group(:currency).calculate_all(:count, :cents_sum))
  end

  def test_many_groups_many_expressions
    create_orders
    expected = {
      ["card", "USD"] => {cents_min: 100, cents_max: 100},
      ["cash", "USD"] => {cents_min: 300, cents_max: 400},
      ["card", "RUB"] => {cents_min: 200, cents_max: 200},
      ["cash", "RUB"] => {cents_min: 500, cents_max: 500}
    }
    assert_equal(expected, Order.group(:kind).group(:currency).calculate_all(:cents_min, :cents_max))
  end

  def test_expression_aliases
    create_orders
    assert_equal({foo: 2}, Order.calculate_all(foo: "count(distinct currency)"))
  end

  def test_returns_only_value_on_no_groups_one_string_expression
    create_orders
    assert_equal(400, Order.calculate_all("MAX(cents) - MIN(cents)"))
  end

  def test_returns_only_value_on_no_groups_and_one_expression_shortcut
    create_orders
    assert_equal({count_distinct_currency: 2}, Order.calculate_all(:count_distinct_currency))
  end

  def test_returns_grouped_values_too_when_in_list_of_expressions
    create_orders
    expected = {
      "cash" => {kind: "cash", count: 3},
      "card" => {kind: "card", count: 2}
    }
    assert_equal expected, Order.group(:kind).calculate_all(:kind, :count)
  end

  def test_returns_grouped_values_too_when_in_list_of_aliased_expressions
    create_orders
    expected = {
      [1, "cash"] => {payment: "cash", total: 400},
      [1, "card"] => {payment: "card", total: 100},
      [2, "card"] => {payment: "card", total: 200},
      [2, "cash"] => {payment: "cash", total: 800}
    }
    assert_equal expected, Order.group(:department_id, :kind).calculate_all(payment: :kind, total: :sum_cents)
  end

  def test_groupdate_with_simple_values
    skip if sqlite? && old_groupdate?

    create_orders
    expected = {
      Date.new(2014) => 2,
      Date.new(2015) => nil,
      Date.new(2016) => 3
    }
    defaults = old_groupdate? ? {default_value: nil} : {}
    assert_equal expected, Order.group_by_year(:created_at, **defaults).calculate_all("count(id)")
  end

  def test_groupdate_with_several_groups
    skip if sqlite? && old_groupdate?

    create_orders
    expected = {
      ["cash", Date.new(2014)] => {count: 1, sum_cents: 300},
      ["card", Date.new(2014)] => {count: 1, sum_cents: 100},
      ["cash", Date.new(2015)] => {},
      ["card", Date.new(2015)] => {},
      ["cash", Date.new(2016)] => {count: 2, sum_cents: 900},
      ["card", Date.new(2016)] => {count: 1, sum_cents: 200}
    }
    defaults = old_groupdate? ? {default_value: {}} : {}
    assert_equal expected, Order.group(:kind).group_by_year(:created_at, **defaults).calculate_all(:count, :sum_cents)
  end

  def test_groupdate_with_value_wrapping
    skip if old_groupdate?

    create_orders
    expected = {
      Date.new(2014) => "2 orders",
      Date.new(2015) => "none",
      Date.new(2016) => "3 orders"
    }
    assert_equal expected, Order.group_by_year(:created_at).calculate_all("count(*)") { |count| count ? "#{count} orders" : "none" }
  end

  def test_groupdate_with_several_groups_and_value_wrapping
    skip if old_groupdate?

    create_orders
    expected = {
      ["cash", Date.new(2014)] => "1 orders, 300 total",
      ["card", Date.new(2014)] => "1 orders, 100 total",
      ["cash", Date.new(2015)] => "0 orders",
      ["card", Date.new(2015)] => "0 orders",
      ["cash", Date.new(2016)] => "2 orders, 900 total",
      ["card", Date.new(2016)] => "1 orders, 200 total"
    }

    assert_equal expected, Order.group(:kind).group_by_year(:created_at).calculate_all(:count, :sum_cents) { |count: 0, sum_cents: nil|
      if sum_cents
        "#{count} orders, #{sum_cents} total"
      else
        "#{count} orders"
      end
    }
  end

  def test_value_wrapping_one_expression_and_no_groups
    create_orders
    assert_equal "5 orders", Order.calculate_all(:count) { |count:| "#{count} orders" }
  end

  def test_value_wrapping_for_one_expression
    create_orders
    expected = {
      "RUB" => "2 orders",
      "USD" => "3 orders"
    }
    assert_equal expected, Order.group(:currency).calculate_all(:count) { |count:|
      "#{count} orders"
    }
  end

  def test_value_wrapping_for_several_expressions
    create_orders
    expected = {
      "RUB" => "2 orders, 350 cents average",
      "USD" => "3 orders, 266 cents average"
    }
    assert_equal expected, Order.group(:currency).calculate_all(:count, :avg_cents) { |stats|
      "#{stats[:count]} orders, #{stats[:avg_cents].to_i} cents average"
    }
  end

  def test_value_wrapping_for_several_expressions_with_keyword_args
    create_orders
    expected = {
      "RUB" => "2 orders, 350 cents average",
      "USD" => "3 orders, 266 cents average"
    }
    assert_equal expected, Order.group(:currency).calculate_all(:count, :avg_cents) { |count:, avg_cents:|
      "#{count} orders, #{avg_cents.to_i} cents average"
    }
  end

  def test_value_wrapping_for_several_expressions_with_constructor
    require "ostruct"
    create_orders
    expected = {
      "RUB" => OpenStruct.new(count: 2, max_cents: 500),
      "USD" => OpenStruct.new(count: 3, max_cents: 400)
    }
    assert_equal expected, Order.group(:currency).calculate_all(:count, :max_cents, &OpenStruct.method(:new))
  end

  def test_returns_array_on_array_aggregate
    skip unless postgresql?

    create_orders
    expected = %W[USD RUB USD USD RUB]
    assert_equal expected, Order.calculate_all("ARRAY_AGG(currency ORDER BY id)")
  end

  def test_returns_array_on_grouped_array_aggregate
    skip unless postgresql?

    create_orders
    expected = {
      "card" => ["USD", "RUB"],
      "cash" => ["USD", "USD", "RUB"]
    }
    assert_equal expected, Order.group(:kind).calculate_all("ARRAY_AGG(currency ORDER BY id)")
  end

  def test_console
    skip unless ENV["CONSOLE"]

    create_orders
    require "irb"
    IRB.start
  end
end
