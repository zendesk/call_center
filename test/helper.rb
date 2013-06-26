require 'bundler/setup'
require 'simplecov'
SimpleCov.start do
  add_filter "lib/call_center/core_ext/object_instance_exec.rb"
  command_name "Unit Tests (#{File.basename(ENV['BUNDLE_GEMFILE'])})"
end if ENV['COVERAGE']
require 'test/unit'
require 'shoulda'
require 'mocha'
require 'bourne'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'call_center'

require 'active_support'
require 'action_pack'
require 'action_controller'

class Test::Unit::TestCase
  def response_from_page_or_rjs
    HTML::Document.new(@body).root
  end

  def body(text, debug = false)
    puts text if debug
    @body = text
  end
end

module CommonCallMethods
  def agents_available?; end
  def voicemail; end
  def voicemail_completed; end
  def routing; end
end
