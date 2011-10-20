# Extension for StateMachine::Machine to store and provide render blocks
class StateMachine::Machine
  attr_accessor :response_blocks
  attr_accessor :before_blocks
  attr_accessor :after_blocks
  attr_accessor :flow_actor_blocks

  def response(state_name, &blk)
    @response_blocks ||= {}
    @response_blocks[state_name] = blk
  end

  def before(state_name, &blk)
    @before_blocks ||= {}
    @before_blocks[state_name] ||= []
    @before_blocks[state_name] << blk
  end

  def after(state_name, &blk)
    @after_blocks ||= {}
    @after_blocks[state_name] ||= []
    @after_blocks[state_name] << blk
  end

  def block_accessor(accessor, for_state)
    return unless respond_to?(accessor)
    blocks = send(accessor)
    blocks[for_state] if blocks
  end

  def flow_actors(name, &blk)
    @flow_actor_blocks ||= {}
    @flow_actor_blocks[name] = blk
  end
end

# Extension for StateMachine::AlternateMachine to provide render blocks inside a state definition
class StateMachine::AlternateMachine
  def response(state_name = nil, &blk)
    if @from_state
      @queued_sends << [[:response, @from_state], blk]
    else
      @queued_sends << [[:response, state_name], blk]
    end
  end

  def before(&blk)
    if @from_state
      @queued_sends << [[:before, @from_state], blk]
    end
  end

  def after(scope = nil, &blk)
    if @from_state
      @queued_sends << [[:after, @from_state], blk]
    end
  end

  def actor(name, &blk)
    (class << self; self; end).send(:define_method, name.to_sym) do |event_name, options|
      event_name = :"#{name}_#{event_name}"
      event(event_name, options)
    end
    @queued_sends << [[:flow_actors, name], blk]
  end
end
