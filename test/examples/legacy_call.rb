class LegacyCall
  include CallCenter
  include CommonCallMethods

  state_machine :state, :initial => :initial do
    event :incoming_call do
      transition :initial => :voicemail, :unless => :agents_available?
      transition :initial => :routing, :if => :agents_available?
    end

    after_transition any => :voicemail, :do => :voicemail
    after_transition any => :routing, :do => :routing

    event :customer_hangs_up do
      transition :voicemail => :voicemail_completed
      transition :routing => :cancelled
      transition :cancelled => same
    end

    after_transition any => :voicemail_completed, :do => :voicemail_completed

    event :something_crazy_happens do
      transition :initial => :uh_oh # No after transition for this one
    end
  end
end