# CalculateAll

Provides `#calculate_all` method on your Active Record models, scopes and relations.
It's a little addition to Active Record's `#count`, `#maximum`, `#minimum`, `#average` and `#sum`.
It allows to fetch all of the above and any other aggregate functions results in one request, with respect to grouping.

Tested on Postgres only right now. It relies on automatic values type-casting of underlying driver.
Suggestions and patches are welcome.

## Usage

```ruby
results = YourModel.yourscopes.group(:grouping1).group(:grouping2)
  .calculate_all(:column1_max, :column2_distinct_count,
    column3_median: 'percentile_cont(0.5) within group (order by column3 desc)')
```

`#calculate_all` tries to mimic magic level of Active Record's `#group, `#count` and `#pluck`
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
