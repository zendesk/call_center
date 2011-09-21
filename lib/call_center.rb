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
          after_transition any => any do |call, transition|
            call.flow_to(transition) if transition.from_name != transition.to_name
          end
        end
        CallCenter.cache(self, state_machine)
      end
      self.call_flow_state_machine_name ||= state_machine.name
      state_machine
    end

    def current_state_machine
      self.state_machines[self.call_flow_state_machine_name]
    end
  end

  module InstanceMethods
    def render(state_machine_name = self.class.call_flow_state_machine_name)
      xml = Builder::XmlMarkup.new
      render_block = current_block_accessor(:render_blocks, state_machine_name)

      xml.instruct!
      xml.Response do
        self.instance_exec(self, xml, &render_block) if render_block
      end
      xml.target!
    end

    def flow_to(transition, state_machine_name = self.class.call_flow_state_machine_name)
      block = current_block_accessor(:flow_to_blocks, state_machine_name)
      self.instance_exec(self, transition, &block) if block
    end

    def draw_call_flow(*args)
      current_state_machine.draw(*args)
    end

    private

    def current_block_accessor(accessor, state_machine_name)
      csm = self.class.state_machines[state_machine_name]
      return unless csm.respond_to?(accessor)
      blocks, name = csm.send(accessor), csm.name
      blocks[current_flow_state(state_machine_name)] if blocks
    end

    def current_state_machine
      self.class.current_state_machine
    end

    def current_flow_state(state_machine_name)
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
