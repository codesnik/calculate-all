$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'calculate-all'

require 'minitest/autorun'

%w(postgresql).each do |adapter|
  ActiveRecord::Base.establish_connection adapter: adapter, database: "calculate_all_test", username: adapter == "mysql2" ? "root" : nil

  ActiveRecord::Migration.create_table :orders, force: true do |t|
    t.string :kind
    t.string :currency
    t.integer :cents
    t.timestamp :created_at
  end
end

class Order < ActiveRecord::Base
end
