$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require "logger"
require "active_record"

if ActiveSupport.respond_to?(:to_time_preserves_timezone)
  ActiveSupport.to_time_preserves_timezone = :zone
end

require "calculate-all"

require "minitest/autorun"
require "minitest/reporters"
Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new(color: true)]
