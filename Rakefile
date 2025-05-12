require "bundler/gem_tasks"
require "rake/testtask"

ADAPTERS = %w[postgresql mysql sqlite]

ADAPTERS.each do |adapter|
  namespace :test do
    task("env:#{adapter}") { ENV["ADAPTER"] = adapter }

    Rake::TestTask.new(adapter => "env:#{adapter}") do |t|
      t.description = "Run tests for #{adapter}"
      t.libs << "test"
      t.libs << "lib"
      t.test_files = FileList["test/**/*_test.rb"]
    end
  end
end

desc "Run all adapter tests"
task test: ADAPTERS.map { |adapter| "test:#{adapter}" }

task default: :test
