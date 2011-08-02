class MultipleFlowCall
  include CallCenter

  call_flow :status, :initial => :ready do
    state :ready do
      event :go, :to => :done
      on_render do |call, x|
        x.Say "Hello World"
      end
    end
  end

  call_flow :outgoing_status, :initial => :outgoing_ready do
    state :outgoing_ready do
      event :outgoing_go, :to => :outgoing_done
      on_render do |call, x|
        x.Say "Hello Outgoing World"
      end
    end
  end
end