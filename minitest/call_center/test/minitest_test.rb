require 'minitest/helper'
require 'call_center/test/minitest/dsl'

require 'test/examples/call'

describe CallCenter::Test::MiniTest::DSL do
  subject { Call.new }
  let(:call_center_state_field) { :state }

  it_should_flow { on(:incoming_call).from(:initial).to(:routing).if(:agents_available?) }
  it_should_flow { on(:incoming_call).from(:initial).to(:voicemail).unless(:agents_available?) }
  it_should_render { is(:initial).expects(:notify).selects("Response>Say", "Hello World") }

  it_should_flow { on(:customer_hangs_up).from(:voicemail).to(:voicemail_completed) }
  it_should_render { is(:voicemail).expects(:notify).selects("Response>Say", "Hello World").selects("Response>Record[action=/voice/calls/flow?event=voicemail_complete&amp;actor=customer]") }

  it_should_flow { on(:something_crazy_happens).from(:initial).to(:uh_oh) }

  it_should_flow { on(:customer_hangs_up).from(:cancelled).to(:cancelled).expects(:cancelled) { |e| e.never } }
end
