# CalculateAll

Provides `#calculate_all` method on your Active Record models, scopes and relations.
It's a little addition to Active Record's `#count`, `#maximum`, `#minimum`, `#average` and `#sum`.
It allows to fetch all of the above and any other aggregate functions results in one request, with respect to grouping.

Tested only with Postgres and Mysql only right now. It relies on automatic values type-casting of underlying driver.

## Usage

```ruby
results = YourModel.yourscopes.group(:grouping1).group(:grouping2)
  .calculate_all(:column1_max, :column2_distinct_count,
    column3_median: 'percentile_cont(0.5) within group (order by column3 desc)')
```

`#calculate_all` tries to mimic magic of Active Record's `#group`, `#count` and `#pluck`
so result type depends on arguments and on groupings.

### Container

If you have no `group()` on underlying scope, `#calculate_all` will return just one result.
If you have one group, it will return hash of results, with simple keys.
If you have two or more groupings, each result will have an array as a key.

### Results

If you provide just one argument to `#calculate_all`, its calculated value will be returned as is.
Otherwise results would be returned as hash(es) with symbol keys.

so, `Model.calculate_all(:count)` will return just a single integer,
but `Model.group(:foo1, :foo2).calculate_all(expr1: 'count(expr1)', expr2: 'count(expr2)')` will return
something like this:

```ruby
{
  ['foo1_1', 'foo2_1'] => {expr1: 0, expr2: 1},
  ['foo1_1', 'foo2_2'] => {expr1: 2, expr2: 3},
  ...
}
```

### Conversion, formatting, value objects

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
  Model.group_by_year(:created_at, last: 5, default_value: {}).calculate_all(:price_min, :price_max)
  => {
    Sun, 01 Jan 2012 00:00:00 UTC +00:00=>{},
    Tue, 01 Jan 2013 00:00:00 UTC +00:00=>{},
    Wed, 01 Jan 2014 00:00:00 UTC +00:00=>{},
    Thu, 01 Jan 2015 00:00:00 UTC +00:00=>{},
    Fri, 01 Jan 2016 00:00:00 UTC +00:00=>{:price_min=>100, :price_max=>500}
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
