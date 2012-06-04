class DynamicTransitionCall
  include CallCenter
  include CommonCallMethods

  call_flow :state, :initial => :initial do
    state :initial do
      response do |x|
        x.Say "Hello World"
      end

      flow_if :agents_available? do
        flow_if :via_phone? do
          event :incoming_call, :to => :routing_on_phone
        end

        flow_unless :via_phone? do
          event :incoming_call, :to => :routing_on_client
        end
      end

      flow_unless :agents_available? do
        flow_unless :voicemail_full? do
          event :incoming_call, :to => :voicemail
        end

        flow_if :voicemail_full? do
          event :incoming_call, :to => :cancelled
        end
      end
    end

    state :routing_on_client do
      flow_if :out_of_area? do
        event :picks_up, :to => :cancelled
      end
      flow_unless :out_of_area? do
        event :picks_up, :to => :in_conference
      end
    end
  end
end
