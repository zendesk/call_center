require 'call_center/core_ext/object_instance_exec'
require 'state_machine'
require 'call_center/state_machine_ext'

module CallCenter
  def self.included(base)
    base.send(:include, InstanceMethods)
    base.extend(ClassMethods)
  end

  class << self
    attr_accessor :cached_state_machines
  end
  self.cached_state_machines ||= {}

  def self.cache(klass, state_machine)
    self.cached_state_machines["#{klass.name}_#{state_machine.name}"] ||= state_machine
  end

  def self.cached(klass, state_machine_name)
    self.cached_state_machines["#{klass.name}_#{state_machine_name}"]
  end

  def self.render_twiml
    xml = Builder::XmlMarkup.new
    xml.instruct!
    xml.Response do
      yield(xml)
    end
    xml.target!
  end

  module ClassMethods
    attr_accessor :call_flow_state_machine_name

    # Calls state_machine ... with :syntax => :alternate
    def call_flow(*args, &blk)
      options = args.last.is_a?(Hash) ? args.pop : {}
      args << options.merge(:syntax => :alternate)
      state_machine_name = args.first || :state
      if state_machine = CallCenter.cached(self, state_machine_name)
        state_machine = state_machine.duplicate_to(self)
      else
        state_machine = state_machine(*args, &blk)
        state_machine.instance_eval do
          before_transition any => any do |call, transition|
            call.run_blocks(:before_blocks, transition)
          end
          after_transition any => any do |call, transition|
            call.run_blocks(:after_blocks, transition)
          end
        end
        setup_flow_actor_blocks(state_machine)

        CallCenter.cache(self, state_machine)
      end
      self.call_flow_state_machine_name ||= state_machine.name
      state_machine
    end

    def setup_flow_actor_blocks(state_machine)
      return unless state_machine.flow_actor_blocks
      state_machine.flow_actor_blocks.each do |actor, block|
        define_method(actor) do |event|
          self.instance_exec(self, event, &block) if block
        end
      end
    end

    def current_state_machine
      self.state_machines[self.call_flow_state_machine_name]
    end
  end

  module InstanceMethods
    def render(name = nil)
      name ||= self.class.call_flow_state_machine_name
      return unless name
      CallCenter.render_twiml do |xml|
        if render_block = state_machine_for_name(name).block_accessor(:response_blocks, current_state(name))
          render_block.arity == 2 ? self.instance_exec(xml, self, &render_block) : self.instance_exec(xml, &render_block)
        end
      end
    end

    def run_blocks(accessor, transition)
      return if transition.loopback?
      blocks = transition.machine.block_accessor(accessor, transition.to_name) || []
      blocks.each do |block|
        self.instance_exec(self, transition, &block)
      end
    end

    def draw_call_flow(*args)
      self.class.current_state_machine.draw(*args)
    end

    private

    def state_machine_for_name(state_machine_name)
      self.class.state_machines[state_machine_name]
    end

    def current_state(state_machine_name)
      send(state_machine_name).to_sym
    end

    def method_missing(*args, &blk)
      method_name = args.first.to_s
      if method_name =~ /^redirect_and_(.+)!$/
        args.shift
        redirect_to($1.to_sym, *args)
      else
        super
      end
    end
  end
end
