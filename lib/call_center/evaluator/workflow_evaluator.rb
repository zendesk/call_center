##
# Converts a Twilio Workflow into a StateMachine::Machine
class CallCenter::WorkflowEvaluator
  def initialize(actor, reader)
    @actor, @reader = actor, reader
  end

  def evaluate!
    state_machine = machinize!
    actor = @actor
    class << actor
      attr_accessor :call_flow_machine_name
    end
    actor.call_flow_machine_name = state_machine.name
    store_render_blocks!(actor.call_flow_machine_name)
  end

  def machinize!
    actor = @actor
    class << actor
      attr_accessor :call_flow_reader
    end
    actor.call_flow_reader = @reader
    actor.state_machine *@reader.machine_args do
      CallCenter::WorkflowEvaluator.write_events(actor.call_flow_reader.events, self)
    end
  end

  def self.write_events(events, state_machine)
    events.each do |event_name, transitions|
      CallCenter::WorkflowEvaluator.write_event(event_name, transitions, state_machine)
      CallCenter::WorkflowEvaluator.write_after_transitions(transitions, state_machine)
    end
  end

  def self.write_event(event_name, transitions, state_machine)
    state_machine.event event_name do
      CallCenter::WorkflowEvaluator.write_event_transitions(transitions, self)
    end
  end

  def self.write_event_transitions(transitions, state_machine)
    transitions.each do |trans|
      trans.write_event_transition(state_machine)
    end
  end

  def self.write_after_transitions(transitions, state_machine)
    transitions.each do |trans|
      trans.write_after_transition(state_machine)
    end
  end

  def store_render_blocks!(machine_name)
    actor = @actor
    class << actor
      attr_accessor :call_flow_render_block_info
    end
    actor.call_flow_render_block_info = [@reader.render_blocks, machine_name]
  end
end