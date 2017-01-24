require 'test_helper'

class CalculateAllMysqlTest < Minitest::Test

  def db_credentials
    { adapter: 'mysql2', database: 'calculate_all_test', username: 'root' }
  end

  def setup
    super unless defined? @@connected
    @@connected = true
  end

  include CalculateAllCommon

end
