class Call
  include CallCenter
  include CommonCallMethods

  call_flow :state, :initial => :initial do
    actor :customer do |call, event|
      "/voice/calls/flow?event=#{event}&actor=customer"
    end
    actor :agent do |call, event|
      "/voice/calls/flow?event=#{event}&actor=agent"
    end

    state :initial do
      response do |x, call| # To allow defining render blocks within a state
        call.notify(:rendering_initial)
        x.Say "Hello World"
      end

      event :incoming_call, :to => :voicemail, :unless => :agents_available?
      event :incoming_call, :to => :routing, :if => :agents_available?
      event :something_crazy_happens, :to => :uh_oh
    end

    state :voicemail do
      response do |x| # To allow defining render blocks outside a state
        notify(:rendering_voicemail)
        x.Say "Hello World"
        x.Record :action => customer(:voicemail_complete)
      end

      customer :hangs_up, :to => :voicemail_completed
    end

    state :routing do
      customer :hangs_up, :to => :cancelled
      event :start_conference, :to => :in_conference
    end

    state :cancelled do
      before { notify(:going_to_be_cancelled) }
      before { notify(:i_think) }
      after{ notify(:cancelled) }

      customer :hangs_up, :to => same
    end
  end
end
