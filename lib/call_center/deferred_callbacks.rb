module CallCenter
  module DeferredCallbacks
    def self.included(base)
      base.class_eval do
        attr_accessor :call_flow_dfd_callbacks

        def call_flow_callbacks_deferred?
          true
        end

        def call_flow_defer_callback(callback, transition)
          @call_flow_dfd_callbacks ||= {}
          @call_flow_dfd_callbacks[call_flow_state_machine_name] ||= {}
          @call_flow_dfd_callbacks[call_flow_state_machine_name][:before_transition] ||= []
          @call_flow_dfd_callbacks[call_flow_state_machine_name][:after_transition] ||= []
          @call_flow_dfd_callbacks[call_flow_state_machine_name][:after_failure] ||= []


          @call_flow_dfd_callbacks[call_flow_state_machine_name][:before_transition] << [callback, transition] if callback.before
          @call_flow_dfd_callbacks[call_flow_state_machine_name][:after_transition] << [callback, transition] if callback.after && callback.success
          @call_flow_dfd_callbacks[call_flow_state_machine_name][:after_failure] << [callback, transition] if callback.after && callback.failure
        end

        def call_flow_run_deferred(group)
          return unless all_callbacks = @call_flow_dfd_callbacks
          return unless callbacks_groups = @call_flow_dfd_callbacks[call_flow_state_machine_name]
          return unless callbacks = callbacks_groups[group]
          callbacks.each do |set|
            callback, transition = set
            callback.run(self, transition)
          end
          callbacks_groups[group] = []
        end
      end
    end
  end
end
