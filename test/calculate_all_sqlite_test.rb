require 'test_helper'

class CalculateAllSqliteTest < Minitest::Test

  def db_credentials
    { adapter: 'sqlite3', database: ':memory:' }
  end

  def setup
    super unless defined? @@connected
    @@connected = true
  end

  include CalculateAllCommon

end
