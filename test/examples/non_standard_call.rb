class NonStandardCall
  include CallCenter

  call_flow :status, :initial => :ready do
    state :ready do
      on_render do |call, x|
        x.Say "Hello World"
      end
    end
  end
end
