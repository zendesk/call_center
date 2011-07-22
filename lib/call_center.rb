require 'call_center/core_ext/object_instance_exec'
require 'state_machine'

module CallCenter
  autoload :WorkflowReader, 'call_center/evaluator/workflow_reader'
  autoload :WorkflowEvaluator, 'call_center/evaluator/workflow_evaluator'
  autoload :WorkflowTransition, 'call_center/evaluator/workflow_transition'

  def self.included(base)
    base.send(:include, InstanceMethods)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def call_flow(*args, &blk)
      reader = WorkflowReader.new(*args, &blk)
      evaluator = WorkflowEvaluator.new(self, reader)
      evaluator.evaluate!
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
      render_blocks, name = self.class.call_flow_render_block_info
      render_blocks[send(name).to_sym]
    end

    def current_state_machine
      klass = self.class
      klass.state_machines[klass.call_flow_machine_name]
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
