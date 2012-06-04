module CallCenter
  class ConditionalStack
    def initialize
      @stack = []
    end

    def <<(obj)
      @stack << obj
    end

    def pop
      @stack.pop
    end

    def any?
      @stack.any?
    end

    def inject(options)
      current_stack = @stack.dup
      options.merge(:if => lambda { |model|
        current_stack.map { |conditional| conditional.evaluate(model) }.all?
      })
    end

    class Conditional
      attr_reader :name

      def initialize(name)
        @name = name
      end

      def evaluate(model)
        result = model.send(@name)
        if? ? result : !result
      end
    end

    class IfConditional < Conditional
      def if?
        true
      end
    end

    class UnlessConditional < Conditional
      def if?
        false
      end
    end
  end
end
