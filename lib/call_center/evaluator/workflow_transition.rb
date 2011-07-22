# Used by the workflow evaluator to write transitions into a StateMachine::Machine
class CallCenter::WorkflowTransition
  attr_reader :from, :to, :options
  def initialize(from, to, options)
    @from, @to, @options = from, to, options
  end

  def write_event_transition(state_machine)
    state_machine.transition(@options.merge(@from => @to))
  end

  def write_after_transition(state_machine)
    to = @to
    state_machine.after_transition @from => @to do |acting, transition|
      acting.send(to) if to.kind_of?(Symbol) && acting.respond_to?(to)
    end
  end
end
