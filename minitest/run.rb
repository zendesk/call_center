project_root = File.expand_path('..', File.dirname(__FILE__))
lib_dir      = File.join(project_root, 'lib')
test_dir     = File.join(project_root, 'minitest')

begin
  require 'minitest/reporters'
  MiniTest::Unit.runner = MiniTest::SuiteRunner.new
  MiniTest::Unit.runner.reporters << MiniTest::Reporters::ProgressReporter.new
rescue LoadError
  puts "MiniTest::Reporters not available."
end

puts "\n\n"
test_files = File.join(test_dir, '**/*_test.rb')
Dir[test_files].each { |file| require file }
