class NonStandardCall
  include CallCenter

  call_flow :status, :initial => :ready do
    state :ready do
      event :go, :to => :done
      on_render do |call, x|
        x.Say "Hello World"
      end
    end
  end
end
