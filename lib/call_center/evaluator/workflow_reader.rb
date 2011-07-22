##
# Reads a twilio workflow definition
class CallCenter::WorkflowReader
  include StateMachine::MatcherHelpers

  attr_reader :machine_args
  attr_reader :events
  attr_reader :render_blocks

  def initialize(*args, &blk)
    @machine_args = args
    @events = {}
    @render_blocks = {}
    @from_state = nil
    instance_eval(&blk)
  end

  ##
  # Helper for reading states
  class StateReader
    def initialize(state, reader)
      @from_state, @reader = state, reader
    end

    def on_render(*args, &blk)
      @reader.on_render(@from_state, &blk)
    end

    def method_missing(*args, &blk)
      @reader.send(*args, &blk)
    end
  end

  def state(*args, &blk)
    @from_state = args.first
    evaluator = StateReader.new(@from_state, self)
    evaluator.instance_eval(&blk)
  end

  def event(event_name, options = {}, &blk)
    to_state = options.delete(:to)
    event_name = event_name.to_sym
    @events[event_name] ||= []
    @events[event_name] << CallCenter::WorkflowTransition.new(@from_state, to_state, options)
  end

  def on_render(state = nil, &blk)
    state_name = state.to_sym
    @render_blocks[state_name] = blk
  end
end