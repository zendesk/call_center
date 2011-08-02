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

  def self.cache(klass)
    self.cached_state_machines[klass.name] ||= klass.current_state_machine
  end

  module ClassMethods
    attr_accessor :call_flow_state_machine_name

    # Calls state_machine ... with :syntax => :alternate
    def call_flow(*args, &blk)
      options = args.last.is_a?(Hash) ? args.pop : {}
      args << options.merge(:syntax => :alternate)
      if !defined?(state_machines) && state_machine = CallCenter.cached_state_machines[self.name]
        state_machine = state_machine.duplicate_to(self)
        self.call_flow_state_machine_name = state_machine.name
      else
        state_machine = state_machine(*args, &blk)
        self.call_flow_state_machine_name = state_machine.name
        CallCenter.cache(self)
      end
      state_machine
    end

    def current_state_machine
      self.state_machines[self.call_flow_state_machine_name]
    end
  end

  module InstanceMethods
    def render
      xml = Builder::XmlMarkup.new
      render_block = current_render_block

      xml.instruct!
      xml.Response do
        self.instance_exec(self, xml, &render_block) if render_block
      end
      xml.target!
    end

    def draw_call_flow(*args)
      current_state_machine.draw(*args)
    end

    private

    def current_render_block
      csm = current_state_machine
      render_blocks, name = csm.render_blocks, csm.name
      render_blocks[send(name).to_sym] if render_blocks
    end

    def current_state_machine
      self.class.current_state_machine
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
