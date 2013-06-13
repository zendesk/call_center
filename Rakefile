require 'bundler/setup'
require 'appraisal'
require 'bundler/gem_tasks'
require 'bump/tasks'

#require 'rcov/rcovtask'
#Rcov::RcovTask.new do |test|
#  test.pattern = 'test/**/*_test.rb'
#  test.verbose = true
#  test.rcov_opts << '--exclude "gems/*,lib/call_center/core_ext/object_instance_exec.rb"'
#end

require 'rake/testtask'
task :test => ["test:unit", "test:dsl"]
namespace :test do
  Rake::TestTask.new(:unit) do |test|
    test.pattern = 'test/**/*_test.rb'
    test.verbose = true
  end

  Rake::TestTask.new(:dsl) do |t|
    t.pattern = "minitest/**/*_test.rb"
  end
end

desc "Run all tests."
task :default do
  sh "rake appraisal:install appraisal:relativize && rake appraisal test"
end

namespace :appraisal do
  task :relativize do
    Dir["gemfiles/*.lock"].each do |file|
      content = File.read(file)
      content.gsub!(File.dirname(__FILE__), "../")
      File.open(file, "w") { |f| f.write(content) }
    end
  end
end
