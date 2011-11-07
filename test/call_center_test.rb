require 'helper'

require 'call_center/test/dsl'

require 'test/examples/legacy_call'
require 'test/examples/call'
require 'test/examples/non_standard_call'
require 'test/examples/multiple_flow_call'

class CallCenterTest < Test::Unit::TestCase
  include CallCenter::Test::DSL

  [:call, :legacy_call].each do |call_type|
    context "#{call_type.to_s.gsub('_', ' ')} workflow" do
      setup do
        klass = call_type.to_s.gsub('_', ' ').titleize.gsub(' ', '').constantize
        @call = klass.new
        @call.stubs(:notify)
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
          @call.stubs(:cancelled)
          @call.state = 'cancelled'

          @call.customer_hangs_up!

          assert @call.cancelled?
          assert_received(@call, :cancelled) { |e| e.never }
        end
      end

      context "using test DSL:" do
        should_flow :on => :incoming_call, :initial => :routing, :when => Proc.new {
          @call.stubs(:agents_available?).returns(true)
        }

        should_flow :on => :incoming_call, :initial => :voicemail, :when => Proc.new {
          @call.stubs(:agents_available?).returns(false)
        } do
          should_flow :on => :customer_hangs_up, :voicemail => :voicemail_completed
        end

        should_flow :on => :something_crazy_happens, :initial => :uh_oh

        should_flow :on => :customer_hangs_up, :cancelled => :cancelled do
          should_also { assert_received(@call, :cancelled) { |e| e.never } }
        end
      end
    end
  end

  context "call" do
    setup do
      @call = Call.new
    end

    should "render xml for initial state" do
      @call.expects(:notify).with(:rendering_initial)
      body @call.render
      assert_select "Response>Say", "Hello World"
    end

    should "return customer url for event" do
      assert_equal("/voice/calls/flow?event=voicemail_complete&actor=customer", @call.customer(:voicemail_complete))
    end

    should "return agent url for event" do
      assert_equal("/voice/calls/flow?event=voicemail_complete&actor=agent", @call.agent(:voicemail_complete))
    end

    should "render xml for voicemail state" do
      @call.stubs(:agents_available?).returns(false)
      @call.incoming_call!
      @call.expects(:notify).with(:rendering_voicemail)

      body @call.render
      assert_select "Response>Say"
      assert_select "Response>Record[action=/voice/calls/flow?event=voicemail_complete&actor=customer]"
    end

    should "render noop when no render block" do
      @call.stubs(:agents_available?).returns(true)
      @call.incoming_call!

      body @call.render
      assert_select "Response"
    end

    should "execute callbacks" do
      @call.state = 'cancelled'

      @call.expects(:notify).with(:before_always).times(3)
      @call.expects(:notify).with(:before_always_uniq).times(1)

      @call.expects(:notify).with(:after_always).times(4)
      @call.expects(:notify).with(:after_success).times(3)
      @call.expects(:notify).with(:after_failure).times(1)

      @call.expects(:notify).with(:after_always_uniq).times(1)
      @call.expects(:notify).with { |notification, transition| notification == :after_success_uniq && transition.kind_of?(StateMachine::Transition) }.times(1)
      @call.expects(:notify).with(:after_failure_uniq).times(0)

      @call.customer_end!
      @call.customer_end!
      @call.customer_end!
      assert(!@call.customer_hangs_up)
    end

    should "execute callbacks in sequence" do
      seq = sequence('callback_sequence')
      @call.state = 'cancelled'

      @call.expects(:notify).with(:before_always).in_sequence(seq)
      @call.expects(:notify).with(:before_always_uniq).in_sequence(seq)

      @call.expects(:notify).with(:after_always).in_sequence(seq)
      @call.expects(:notify).with(:after_success).in_sequence(seq)

      @call.expects(:notify).with(:after_always_uniq).in_sequence(seq)
      @call.expects(:notify).with(:after_success_uniq, anything).in_sequence(seq)

      @call.customer_end!
    end

    should "defer callbacks" do
      (class << @call; self; end).class_eval do
        include CallCenter::DeferredCallbacks
      end
      @call.state = 'cancelled'

      @call.expects(:notify).with(:before_always).never
      @call.expects(:notify).with(:before_always_uniq).never

      @call.expects(:notify).with(:after_always).never
      @call.expects(:notify).with(:after_success).never
      @call.expects(:notify).with(:after_failure).never

      @call.expects(:notify).with(:after_always_uniq).never
      @call.expects(:notify).with(:after_success_uniq, anything).never

      @call.customer_end!
      assert(!@call.customer_hangs_up)

      # Ready for deferred callbacks

      seq = sequence('callback_sequence')

      @call.expects(:notify).with(:before_always)
      @call.expects(:notify).with(:before_always_uniq)

      @call.call_flow_run_deferred(:before_transition)

      @call.expects(:notify).with(:after_always).times(2)
      @call.expects(:notify).with(:after_success)

      @call.expects(:notify).with(:after_always_uniq)
      @call.expects(:notify).with(:after_success_uniq, anything)

      @call.call_flow_run_deferred(:after_transition)

      @call.expects(:notify).with(:after_always).times(2)
      @call.expects(:notify).with(:after_failure)
      @call.expects(:notify).with(:after_always_uniq)

      @call.call_flow_run_deferred(:after_failure)

      # Empty
      @call.call_flow_run_deferred(:before_transition)
      @call.call_flow_run_deferred(:after_transition)
      @call.call_flow_run_deferred(:after_failure)
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

    context "using test DSL:" do
      should_flow :on => :incoming_call, :initial => :voicemail, :when => Proc.new {
        @call.stubs(:agents_available?).returns(false)
        @call.stubs(:notify)
        @call.stubs(:customer).returns('the_flow')
      } do
        should_also { assert_received(@call, :notify) { |e| e.with(:rendering_voicemail) } }
        and_also { assert_received(@call, :customer) { |e| e.with(:voicemail_complete) } }
        and_render { "Response>Say" }
        and_render { "Response>Record[action=the_flow]" }
      end

      should_flow :on => :incoming_call, :initial => :routing, :when => Proc.new {
        @call.stubs(:agents_available?).returns(true)
      } do
        should_render { "Response" }
      end

      should_flow :on => :customer_hangs_up, :routing => :cancelled, :when => Proc.new {
        @call.stubs(:notify)
      } do
        should_also { assert_received(@call, :notify) { |e| e.with(:cancelled).once } }
        and_also { assert @call.cancelled? }

        should_flow :on => :customer_hangs_up, :cancelled => :cancelled do
          should_also { assert_received(@call, :notify) { |e| e.with(:cancelled).once } } # For above
          and_also { assert @call.cancelled? }

          should_flow :on => :customer_hangs_up, :cancelled => :cancelled do
            should_also { assert_received(@call, :notify) { |e| e.with(:cancelled).once } } # For above
            and_also { assert @call.cancelled? }
          end
        end
      end
    end

    context "deferred and using test DSL:" do
      setup do
        (class << @call; self; end).class_eval do
          include CallCenter::DeferredCallbacks
        end
      end

      should_flow :on => :incoming_call, :initial => :voicemail, :when => Proc.new {
        @call.stubs(:agents_available?).returns(false)
        @call.stubs(:notify)
        @call.stubs(:customer).returns('the_flow')
      } do
        should_also { assert_received(@call, :notify) { |e| e.with(:rendering_voicemail) } }
        and_also { assert_received(@call, :customer) { |e| e.with(:voicemail_complete) } }
        and_render { "Response>Say" }
        and_render { "Response>Record[action=the_flow]" }
      end

      should_flow :on => :incoming_call, :initial => :routing, :when => Proc.new {
        @call.stubs(:agents_available?).returns(true)
      } do
        should_render { "Response" }
      end

      should_flow :on => :customer_hangs_up, :routing => :cancelled, :when => Proc.new {
        @call.stubs(:notify)
      } do
        should_also { assert_received(@call, :notify) { |e| e.with(:cancelled).once } }
        and_also { assert @call.cancelled? }

        should_flow :on => :customer_hangs_up, :cancelled => :cancelled do
          should_also { assert_received(@call, :notify) { |e| e.with(:cancelled).once } } # For above
          and_also { assert @call.cancelled? }

          should_flow :on => :customer_hangs_up, :cancelled => :cancelled do
            should_also { assert_received(@call, :notify) { |e| e.with(:cancelled).once } } # For above
            and_also { assert @call.cancelled? }
          end
        end
      end
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

  context "cache call" do
    should "re-apply state machine and render xml for initial state" do
      Object.send(:remove_const, :NonStandardCall)
      Object.const_set(:NonStandardCall, Class.new)
      NonStandardCall.class_eval do
        include CallCenter
        call_flow :status, :initial => :ready do
          raise Exception, "Should not be called"
        end
      end

      @call = NonStandardCall.new

      assert_equal 'ready', @call.status
      body @call.render
      assert_select "Response>Say", "Hello World"
      assert @call.go!
    end
  end

  context "cache multiple call flows" do
    should "re-apply state machine and render xml for initial state" do
      Object.send(:remove_const, :MultipleFlowCall)
      Object.const_set(:MultipleFlowCall, Class.new)
      MultipleFlowCall.class_eval do
        include CallCenter
        call_flow :status, :initial => :ready do
          raise Exception, "Should not be called"
        end
        call_flow :outgoing_status, :initial => :outgoing_ready do
          raise Exception, "Should not be called"
        end
      end

      @call = MultipleFlowCall.new

      assert_equal 'ready', @call.status
      body @call.render
      assert_select "Response>Say", "Hello World"
      assert @call.go!

      assert_equal 'outgoing_ready', @call.outgoing_status
      body @call.render(:outgoing_status)
      assert_select "Response>Say", "Hello Outgoing World"
      assert @call.outgoing_go!
    end
  end
end
