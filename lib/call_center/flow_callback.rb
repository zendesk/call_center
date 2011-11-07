module CallCenter
  class FlowCallback
    attr_reader :state_name, :scope, :block

    def self.create(state_name, scope, options, block)
      case scope
      when :success
        new(state_name, scope, options, block).extend(SuccessFlowCallback)
      when :failure
        new(state_name, scope, options, block).extend(FailureFlowCallback)
      else
        new(state_name, scope, options, block).extend(AlwaysFlowCallback)
      end
    end

    def initialize(state_name, scope, options, block)
      raise "Invalid scope: #{scope} for flow callback" unless [:always, :success, :failure].include?(scope)
      @state_name, @scope, @block = state_name, scope, block
      extend(UniqueFlowCallback) if options[:uniq]
    end

    def run(flow, transition)
      @transition = transition
      flow.instance_exec(transition, &block) if should_run?
    end

    def run_deferred?(call, transition)
      if call.respond_to?(:call_flow_callbacks_deferred?) && call.call_flow_callbacks_deferred?
        call.call_flow_defer_callback(self, transition)
        true
      end
    end

    def setup(context)
      callback = self
      context.send(transition_hook, transition_parameters(context)) do |call, transition|
        callback.run(call, transition) unless callback.run_deferred?(call, transition)
      end
    end

    def before
      true
    end

    def after
      false
    end

    private

    def transition_parameters(context)
      { context.any => @state_name }
    end

    def transition_hook
      :before_transition
    end

    def should_run?
      true
    end
  end

  class AfterFlowCallback < FlowCallback
    def transition_hook
      :after_transition
    end

    def before
      false
    end

    def after
      true
    end
  end

  module AlwaysFlowCallback
    def success; true; end
    def failure; true; end
  end

  module SuccessFlowCallback
    def success; true; end
    def failure; false; end
  end

  module FailureFlowCallback
    def success; false; end
    def failure; true; end
  end

  module UniqueFlowCallback
    def should_run?
      !@transition.loopback?
    end

    def transition_parameters(context)
      { context.any - @state_name => @state_name }
    end
  end
end