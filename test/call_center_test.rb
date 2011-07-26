require 'helper'

require 'test/examples/legacy_call'
require 'test/examples/call'
require 'test/examples/non_standard_call'

class CallCenterTest < Test::Unit::TestCase
  [:call, :legacy_call].each do |call_type|
    context "#{call_type.to_s.gsub('_', ' ')} workflow" do
      setup do
        klass = call_type.to_s.gsub('_', ' ').titleize.gsub(' ', '').constantize
        @call = klass.new
      end

      context "agents available" do
        setup do
          @call.stubs(:agents_available?).returns(true)
        end

        should "transition to routing" do
          @call.incoming_call!
          assert_equal 'routing', @call.state
        end
      end

      context "no agents available "do
        setup do
          @call.stubs(:agents_available?).returns(false)
        end

        should "transition to voicemail" do
          @call.incoming_call!
          assert_equal 'voicemail', @call.state
        end
      end

      context "in voicemail" do
        setup do
          @call.stubs(:agents_available?).returns(false)
          @call.incoming_call!
        end

        context "and customer hangs up" do
          should "transition to voicemail_completed" do
            @call.customer_hangs_up!
            assert @call.voicemail_completed?
          end
        end
      end

      context "something crazy happens" do
        # It's going to try to call the after transition method, but since it doesn't exist...
        should "be ok" do
          @call.something_crazy_happens!
        end
      end

      context "cancelled" do
        should "stay in cancelled" do
          @call.state = 'cancelled'
          @call.expects(:cancelled).never
          @call.customer_hangs_up!
          assert @call.cancelled?
        end
      end
    end
  end

  context "call" do
    setup do
      @call = Call.new
    end

    should  "render xml for initial state" do
      @call.expects(:notify).with(:rendering_initial)
      body @call.render
      assert_select "Response>Say", "Hello World"
    end

    should  "render xml for voicemail state" do
      @call.stubs(:agents_available?).returns(false)
      @call.incoming_call!
      @call.expects(:notify).with(:rendering_voicemail)
      @call.expects(:flow_url).with(:voicemail_complete).returns('the_flow')

      body @call.render
      assert_select "Response>Say"
      assert_select "Response>Record[action=the_flow]"
    end

    should "render noop when no render block" do
      @call.stubs(:agents_available?).returns(true)
      @call.incoming_call!

      body @call.render
      assert_select "Response"
    end

    should "asynchronously perform event" do
      @call.stubs(:agents_available?).returns(true)
      @call.incoming_call!
      @call.expects(:redirect_to).with(:start_conference)

      @call.redirect_and_start_conference!
    end

    should "asynchronously perform event with options" do
      @call.stubs(:agents_available?).returns(true)
      @call.incoming_call!
      @call.expects(:redirect_to).with(:start_conference, :status => 'completed')

      @call.redirect_and_start_conference!(:status => 'completed')
    end

    should "raise error on missing method" do
      assert_raises {
        @call.i_am_missing!
      }
    end

    should "draw state machine digraph" do
      Call.state_machines[:state].expects(:draw).with(:name => 'call_workflow', :font => 'Helvetica Neue')
      @call.draw_call_flow(:name => 'call_workflow', :font => 'Helvetica Neue')
    end
  end

  context "non-standard call" do
    setup do
      @call = NonStandardCall.new
    end

    should "render xml for initial state" do
      assert_equal 'ready', @call.status
      body @call.render
      assert_select "Response>Say", "Hello World"
    end
  end
end
