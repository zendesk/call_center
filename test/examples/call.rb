class Call
  include CallCenter
  include CommonCallMethods

  call_flow :state, :initial => :initial do
    state :initial do
      event :incoming_call, :to => :voicemail, :unless => :agents_available?
      event :incoming_call, :to => :routing, :if => :agents_available?
      event :something_crazy_happens, :to => :uh_oh
    end

    state :voicemail do
      event :customer_hangs_up, :to => :voicemail_completed
    end

    state :routing do
      event :customer_hangs_up, :to => :cancelled
      event :start_conference, :to => :in_conference
    end

    state :cancelled do
      event :customer_hangs_up, :to => same
    end

    # =================
    # = Render Blocks =
    # =================

    state :initial do
      on_render do |call, x| # To allow defining render blocks within a state
        call.notify(:rendering_initial)
        x.Say "Hello World"
      end
    end

    on_render(:voicemail) do |call, x| # To allow defining render blocks outside a state
      notify(:rendering_voicemail)
      x.Say "Hello World"
      x.Record :action => flow_url(:voicemail_complete)
    end
  end
end
