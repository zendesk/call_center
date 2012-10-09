require 'bundler/setup'
require 'minitest/autorun'
require 'shoulda'
require 'mocha'
require 'bourne'

require 'minitest/reporters'
MiniTest::Reporters.use! MiniTest::Reporters::DefaultReporter.new

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
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
