require 'rubygems'
require 'bundler/setup'
require 'minitest/autorun'
require 'mocha'
require 'active_support'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'call_center'

module CommonCallMethods
  def agents_available?; end
  def voicemail; end
  def voicemail_completed; end
  def routing; end
end
