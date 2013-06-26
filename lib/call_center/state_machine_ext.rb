# Extension for StateMachine::Machine to store and provide render blocks
class StateMachine::Machine
  attr_accessor :response_blocks
  attr_accessor :callback_blocks
  attr_accessor :flow_actor_blocks

  def response(state_name, &blk)
    @response_blocks ||= {}
    @response_blocks[state_name] = blk
  end

  def before(state_name, scope, options, &blk)
    @callback_blocks ||= []
    @callback_blocks << CallCenter::FlowCallback.create(state_name, :always, options, blk)
  end

  def after(state_name, scope, options, &blk)
    @callback_blocks ||= []
    @callback_blocks << CallCenter::AfterFlowCallback.create(state_name, scope, options, blk)
  end

  def actor(name, &blk)
    StateMachine::StateContext.send(:define_method, name.to_sym) do |event_name, options|
      event_name = :"#{name}_#{event_name}"
      event(event_name, options)
    end
    flow_actors(name, &blk)
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

  def setup_call_flow(flow)
    setup_success_blocks
    setup_failure_blocks
    setup_flow_actor_blocks(flow)
    self
  end

  def setup_success_blocks
    return unless @callback_blocks
    @callback_blocks.select { |c| c.before || (c.success && c.after) }.each { |callback| callback.setup(self) }
  end

  def setup_failure_blocks
    return unless @callback_blocks
    event_names = events.map(&:name)
    event_names.each do |event_name|
      after_failure :on => event_name do |call, transition|
        callbacks = @callback_blocks.select { |callback| callback.after && callback.state_name == transition.to_name && callback.failure } || []
        callbacks.each { |callback| callback.run(call, transition) unless callback.run_deferred?(call, transition) }
      end
    end
  end

  def setup_flow_actor_blocks(flow_class)
    return unless @flow_actor_blocks
    @flow_actor_blocks.each do |actor, block|
      flow_class.send(:define_method, actor) do |event|
        self.instance_exec(self, event, &block) if block
      end
    end
  end

  def duplicate_to(clazz)
    new_copy = self.clone
    new_copy.owner_class = clazz
    new_copy.define_helpers
    new_copy.define_scopes(@plural)
    new_copy.events.each { |event| event.send(:add_actions) }
    new_copy.states.each { |state| state.send(:add_predicate) }
    new_copy
  end
end

# Extension for StateMachine::StateContext to provide render blocks inside a state definition
class StateMachine::StateContext
  include StateMachine::MatcherHelpers

  attr_accessor :flow_stacks

  def event(name, options = {})
    if flow_stacks && flow_stacks.any?
      options = flow_stacks.inject(options)
    end

    transition(options.update(:on => name))
  end

  def response(&blk)
    machine.response(state.name, &blk)
  end

  def before(scope, options = {}, &blk)
    machine.before(state.name, scope, options, &blk)
  end

  def after(scope, options = {}, &blk)
    machine.after(state.name, scope, options, &blk)
  end

  def flow_if(conditional, &blk)
    self.flow_stacks ||= CallCenter::ConditionalStack.new
    begin
      self.flow_stacks << CallCenter::ConditionalStack::IfConditional.new(conditional)
      yield if block_given?
    ensure
      self.flow_stacks.pop
    end
  end

  def flow_unless(conditional, &blk)
    self.flow_stacks ||= CallCenter::ConditionalStack.new
    begin
      self.flow_stacks << CallCenter::ConditionalStack::UnlessConditional.new(conditional)
      yield if block_given?
    ensure
      self.flow_stacks.pop
    end
  end
end
