# CalculateAll

Provides `#calculate_all` method on your Active Record models, scopes and relations.
It's a little addition to Active Record's `#count`, `#maximum`, `#minimum`, `#average` and `#sum`.
It allows to fetch all of the above and any other aggregate functions results in one request, with respect to grouping.

Tested only with Postgres and MySQL only right now. It relies on automatic values type-casting of underlying driver.

## Usage

```ruby
stats = Order.group(:department_id).group(:payment_method).calculate_all(
  :count,
  :count_distinct_user_id,
  :price_max,
  :price_min,
  :price_avg,
  price_median: 'percentile_cont(0.5) within group (order by price desc)'
)
#
#   (2.2ms)  SELECT department_id, payment_method, percentile_cont(0.5) within group (order by price desc),
#      COUNT(*), COUNT(DISTINCT user_id), MAX(price), MIN(price), AVG(price) FROM "orders" GROUP BY "department_id", "payment_method"
#
# => {
#   [1, "cash"] => {
#     count: 10,
#     count_distinct_user_id: 5,
#     price_max: 500,
#     price_min: 100,
#     price_avg: #<BigDecimal:7ff5932ff3d8,'0.3E3',9(27)>,
#     price_median: #<BigDecimal:7ff5932ff3c2,'0.4E3',9(27)>
#   },
#   [1, "card"] => {
#     ...
#   }
# }
```

## Rationale

Active Record allows to use most common DB aggregate functions, COUNT(), MAX(), MIN(), AVG(), SUM() really easy.
But there's a whole world of wonderful other functions in
[Postgres](http://www.postgresql.org/docs/9.5/static/functions-aggregate.html) which I can't recommend enough
if you going to have any work with statistics and BI on your data, though MySQL has something
[too](http://dev.mysql.com/doc/refman/5.7/en/group-by-functions.html).

Also, in many cases you'll need several metrics at once, and database often has to perform a full scan on
the table for each metric, but it as well can calculate them all in one scan and one request.

`#calculate_all` to the rescue!

## Arguments

`#calculate_all` accepts a list of expression aliases and/or expression mapping.
It could be either one string of SQL,

```ruby
  Model.calculate_all('SUM(price) / COUNT(DISTINCT user_id)')
```

a hash of expressions with arbitrary symbol keys

```ruby
  Model.calculate_all(total: 'COUNT(*)', average_spendings: 'SUM(price) / COUNT(DISTINCT user_id)')
```
or a list of one or more symbols without expressions, in which case `#calculate_all` tries to guess
what you wanted from it.

```ruby
  Model.calculate_all(:count, :average_price, :sum_price)
```

It's not so smart right now, but here's a cheatsheet:

| symbol                                                                 | would fetch
|------------------------------------------------------------------------|------------
| `:count`                                                               | `COUNT(*)`
| `:count_column1`, `:column1_count`                                     | `COUNT(column1)` (doesn't count NULL's in that column)
| `:count_distinct_column1`, `:column1_distinct_count`                   | `COUNT(DISTINCT column1)`
| `:max_column1`, `:column1_max`, `:maximum_column1`, `:column1_maximum` | `MAX(column1)`
| `:min_column1`, `:column1_min`, `:minimum_column1`, `:column1_minimum` | `MIN(column1)`
| `:avg_column1`, `:column1_avg`, `:average_column1`, `:column1_average` | `AVG(column1)`
| `:sum_column1`, `:column1_sum`                                         | `SUM(column1)`

## Result

`#calculate_all` tries to mimic magic of Active Record's `#group`, `#count` and `#pluck`
so result type depends on arguments and on groupings.

If you have no `group()` on underlying scope, `#calculate_all` will return just one result.

```ruby
# same as Order.distinct.count(:user_id), so, probably useless example
# but you can have any expression with aggregate functions there.
Order.calculate_all('COUNT(DISTINCT user_id)')
# => 50
```

If you have one group, it will return hash of results, with simple keys.

```ruby
# again, Order.group(:department_id).distinct.count(:user_id) would do the same
Order.group(:department_id).calculate_all(:count_distinct_user_id)
# => {
#   1 => 20,
#   2 => 10,
#   ...
# }
```

If you have two or more groupings, each result will have an array as a key.

```ruby
Order.group(:department_id).group(:department_method).calculate_all(:count_distinct_user_id)
# => {
#   [1, "cash"] => 5,
#   [1, "card"] => 15,
#   [2, "cash"] => 1,
#   ...
# }
```

If you provide just one argument to `#calculate_all`, its calculated value will be returned as is.
Otherwise results would be returned as hash(es) with symbol keys.

so, `Order.calculate_all(:count)` will return just a single integer, but

```ruby
Order.group(:department_id).group(:payment_method).calculate_all(:min_price, expr1: 'count(distinct user_id)')
# => {
#   [1, 'cash'] => {min_price: 100, expr1: 5},
#   [1, 'card'] => {min_price: 150, expr2: 15},
#   ...
# }
```

You can pass block to calculate_all. Rows will be passed to it and returned value will be used instead of
row in result hash (or returned as is if there's no grouping)

```ruby
Order.group(:country_id).calculate_all(:count, :avg_price) { |count:, avg_price:|
  "#{count} orders, #{avg_price.to_i} dollars average"
}
# => {
#   1 => "5 orders, 120 dollars average",
#   2 => "10 orders, 200 dollars average"
# }

Order.group(:country_id).calculate_all(:avg_price) { |avg_price| avg_price.to_i }
# => {
#   1 => 120,
#   2 => 200
# }

Order.calculate_all(:count, :max_price, &OpenStruct.method(:new))
# => #<OpenStruct max_price=500, count=15>
```

## groupdate compatibility

calculate-all should work with [groupdate](https://github.com/ankane/groupdate) too:

```ruby
Order.group_by_year(:created_at, last: 5).calculate_all(:price_min, :price_max)
=> {
  Sun, 01 Jan 2012 => {},
  Tue, 01 Jan 2013 => {},
  Wed, 01 Jan 2014 => {},
  Thu, 01 Jan 2015 => {},
  Fri, 01 Jan 2016 => {:price_min=>100, :price_max=>500}
}
```

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

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/codesnik/calculate-all.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
