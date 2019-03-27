require "bundler/gem_tasks"
require "cucumber/rake/task"

Cucumber::Rake::Task.new

task :default => [ "cucumber" ]

begin
  require "kitchen/rake_tasks"
  Kitchen::RakeTasks.new
rescue LoadError
  puts ">>>>> Kitchen gem not loaded, omitting tasks" unless ENV["CI"]
end
