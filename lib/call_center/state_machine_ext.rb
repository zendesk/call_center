# Extension for StateMachine::Machine to store and provide render blocks
class StateMachine::Machine
  attr_accessor :render_blocks
  attr_accessor :flow_to_blocks

  def on_render(state_name, &blk)
    @render_blocks ||= {}
    @render_blocks[state_name] = blk
  end

  def on_flow_to(state_name, &blk)
    @flow_to_blocks ||= {}
    @flow_to_blocks[state_name] = blk
  end
end

# Extension for StateMachine::AlternateMachine to provide render blocks inside a state definition
class StateMachine::AlternateMachine
  def on_render(state_name = nil, &blk)
    if @from_state
      @queued_sends << [[:on_render, @from_state], blk]
    else
      @queued_sends << [[:on_render, state_name], blk]
    end
  end
end
