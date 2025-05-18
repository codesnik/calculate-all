# CalculateAll

Provides the `#calculate_all` method for your Active Record models, scopes and relations.
It's a small addition to Active Record's `#count`, `#maximum`, `#minimum`, `#average`, `#sum`
and `#calculate`.
It allows you to fetch all of the above, as well as other aggregate function results,
in a single request, with support for grouping.

Should be useful for dashboards, timeseries stats, and charts.

Currently tested with PostgreSQL, MySQL and SQLite3, ruby >= 2.3, rails >= 4, groupdate >= 4.

## Usage

(example SQL snippets are given for PostgreSQL)

```ruby
stats = Order.group(:department_id).group(:payment_method).order(:payment_method).calculate_all(
  :payment_method,
  :count,
  :price_max,
  :price_min,
  :price_avg,
  total_users: :count_distinct_user_id,
  price_median: "percentile_cont(0.5) within group (order by price asc)",
  plan_ids: "array_agg(distinct plan_id order by plan_id)",
  earnings: "sum(price) filter (where status = 'paid')"
)
#   Order Pluck (20.0ms)  SELECT "orders"."department_id", "payment_method", COUNT(*), MAX(price), MIN(price), AVG(price),
#        COUNT(DISTINCT user_id), percentile_cont(0.5) within group (order by price asc),
#        array_agg(distinct plan_id order by plan_id), sum(price) filter (where status = 'paid')
#      FROM "orders" GROUP BY "orders"."department_id", "payment_method" ORDER BY "payment_method" ASC
# => {
#   [1, "card"] => {
#     payment_method: "card",
#     count: 10,
#     price_max: 500,
#     price_min: 100,
#     price_avg: 0.3e3,
#     total_users: 5,
#     price_median: 0.4e3,
#     plan_ids: [4, 7, 12],
#     earnings: 2340
#   },
#   [1, "cash"] => {
#     ...
#   }
# }
```

## Rationale

Active Record makes it really easy to use most common database aggregate functions like COUNT(), MAX(), MIN(), AVG(), SUM().
But there's a whole world of other aggregate functions in
[PostgreSQL](http://www.postgresql.org/docs/current/functions-aggregate.html),
[MySQL](https://dev.mysql.com/doc/refman/9.3/en/aggregate-functions.html)
and [SQLite](https://www.sqlite.org/lang_aggfunc.html)
which I can’t recommend enough, especially if you’re working with statistics or business intelligence.

Also, in many cases, you’ll need multiple metrics at once. Typically, the database performs a full scan of the table for each metric.
However, it can calculate all of them in a single scan and a single request.

`#calculate_all` to the rescue!

## Arguments

`#calculate_all` accepts a single SQL expression with aggregate functions,

```ruby
  Model.calculate_all('CAST(SUM(price) as decimal) / COUNT(DISTINCT user_id)')
```

or arbitrary symbols and keyword arguments with SQL snippets, aggregate function shortcuts or previously given grouping values.

```ruby
  Model.group(:currency).calculate_all(
    :average_price, :currency, total: :sum_price, average_spendings: 'SUM(price)::decimal / COUNT(DISTINCT user_id)'
  )
```

For convenience, `calculate_all(:count, :avg_column)` is the same as `caculate(count: :count, avg_column: :avg_column)`

Here's a cheatsheet of recognized shortcuts:

| symbol                                                                 | would fetch
|------------------------------------------------------------------------|------------
| `:count`                                                               | `COUNT(*)`
| `:count_column1`, `:column1_count`                                     | `COUNT(column1)` (doesn't count NULL's in that column)
| `:count_distinct_column1`, `:column1_distinct_count`                   | `COUNT(DISTINCT column1)`
| `:max_column1`, `:column1_max`, `:maximum_column1`, `:column1_maximum` | `MAX(column1)`
| `:min_column1`, `:column1_min`, `:minimum_column1`, `:column1_minimum` | `MIN(column1)`
| `:avg_column1`, `:column1_avg`, `:average_column1`, `:column1_average` | `AVG(column1)`
| `:sum_column1`, `:column1_sum`                                         | `SUM(column1)`

Other functions are a bit too database specific, and are better to be given with an explicit SQL snippet.

Please don't put values from unverified sources (like HTML form or javascript call) into expression list,
it could result in malicious SQL injection.

## Result

`#calculate_all` tries to mimic magic of Active Record's `#group`, `#count` and `#pluck`
so result type depends on arguments and on groupings.

If you have no `group()` on underlying scope, `#calculate_all` will return just one row.

```ruby
Order.calculate_all(:price_sum)
# => {price_sum: 123500}
```

If you have a single `group()`, it will return a hash of results with simple keys.

```ruby
Order.group(:department_id).calculate_all(:count_distinct_user_id)
# => {
#   1 => {count_distinct_user_id: 20},
#   2 => {count_distinct_user_id: 10},
#   ...
# }
```

If you have two or more groupings, each result will have an array as a key.

```ruby
Order.group(:department_id).group(:department_method).calculate_all(:count)
# => {
#   [1, "cash"] => {count: 5},
#   [1, "card"] => {count: 15},
#   [2, "cash"] => {count: 1},
#   ...
# }
```

If you provide only one *string* argument to `#calculate_all`, its calculated value will be returned as-is.
This is just to make grouped companion to `Model.group(...).count` and friends, but for arbitrary expressions
with aggregate functions.

```ruby
Order.group(:payment_method).calculate_all('CAST(SUM(price) AS decimal) / COUNT(DISTINCT user_id)')
# => {
#   "card" => 0.524e3
#   "cash" => 0.132e3
# }
```

Otherwise, the results will be returned as hash(es) with symbol keys.

```ruby
Order.group(:department_id).group(:payment_method).calculate_all(
  :min_price, type: :payment_method, expr1: 'count(distinct user_id)'
)
# => {
#   [1, 'cash'] => {min_price: 100, type: 'cash', expr1: 5},
#   [1, 'card'] => {min_price: 150, type: 'card', expr1: 15},
#   ...
# }
```

You can pass a block to `calculate_all`. Rows will be passed to it, and returned value will be used instead of
the row in the result hash (or returned as-is if there's no grouping).

```ruby
Order.group(:country_id).calculate_all(:count, :avg_price) { |count:, avg_price:|
  "#{count} orders, #{avg_price.to_i} dollars average"
}
# => {
#   1 => "5 orders, 120 dollars average",
#   2 => "10 orders, 200 dollars average"
# }

Order.group(:country_id).calculate_all("AVG(price)") { |avg_price| avg_price.to_i }
# => {
#   1 => 120,
#   2 => 200
# }

Order.calculate_all(:count, :max_price, &OpenStruct.method(:new))
# => #<OpenStruct max_price=500, count=15>

Stats = Data.define(:count, :max_price) do
  # needed only for groupdate to provide defaults for empty periods
  def initialize(count: 0, max_price: nil) = super
end
Order.group_by_year(:created_at).calculate_all(*Stats.members, &Stats.method(:new))
# => {
#   Wed, 01 Jan 2014 => #<data Stats count=2, max_price=700>,
#   Thu, 01 Jan 2015 => #<data Stats count=0, max_price=nil>,
#   Fri, 01 Jan 2016 => #<data Stats count=3, max_price800>
# }
```

## groupdate compatibility

calculate-all should work with [groupdate](https://github.com/ankane/groupdate) too:

```ruby
Order.group_by_year(:created_at, last: 5).calculate_all(:price_min, :price_max)
# => {
#   Sun, 01 Jan 2012 => {},
#   Tue, 01 Jan 2013 => {},
#   Wed, 01 Jan 2014 => {},
#   Thu, 01 Jan 2015 => {},
#   Fri, 01 Jan 2016 => {:price_min=>100, :price_max=>500}
# }
```

It works even with groupdate < 4, though you'd have to explicitly provide `default_value: {}` for blank periods.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'calculate-all'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install calculate-all

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests.
Run `BUNDLE_GEMFILE=gemfiles/activerecord60.gemfile bundle` then `BUNDLE_GEMFILE=gemfiles/activerecord60.gemfile rake`
to test agains specific active record version.

To experiment you can load a test database and jump to IRB with

```sh
   rake VERBOSE=1 CONSOLE=1 TESTOPTS="--name=test_console" test:postgresql
```

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version
number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags,
and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/codesnik/calculate-all.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
