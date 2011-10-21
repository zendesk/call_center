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
      after(:success, :uniq => true) { notify(:cancelled) }

      customer :hangs_up, :to => same
      customer :end, :to => :ended
    end

    response(:cancelled) do |x, call|
      # Just for sake of comparison
    end

    state :ended do
      after(:always) { notify(:after_always) }
      after(:success) { notify(:after_success) }
      after(:failure) { notify(:after_failure) }

      after(:always, :uniq => true) { notify(:after_always_uniq) }
      after(:success, :uniq => true) { |transition| notify(:after_success_uniq, transition) }
      after(:failure, :uniq => true) { notify(:after_failure_uniq) }

      before(:always) { notify(:before_always) }
      before(:always, :uniq => true) { notify(:before_always_uniq) }

      customer :end, :to => same
    end
  end
end
