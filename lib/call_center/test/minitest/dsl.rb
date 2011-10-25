require 'action_controller/vendor/html-scanner'
require 'action_controller/assertions/selector_assertions'
require 'test/unit/assertions'

module CallCenter
  module Test
    module MiniTest
      module DSL
        class ItShouldFlow
          def initialize(context, &block)
            @context = context
            self.instance_eval(&block) if block_given?
          end

          def on(event)
            @event = event
            self
          end

          def from(from_state)
            @from = from_state.to_s
            self
          end

          def to(to_state)
            @to = to_state.to_s
            self
          end

          class Expectation
            attr_reader :name

            def initialize(name)
              @name = name
            end

            def setup(object)
              raise 'Implement in subclass'
            end
          end

          class Expects < Expectation
            def initialize(name, &blk)
              super(name)
              @expectation_block = blk
            end

            def setup(object)
              mocka = object.expects(name)
              @expectation_block.call(mocka) if @expectation_block
            end
          end

          class Stubs < Expects
            def setup(object)
              mocka = object.stubs(name)
              @expectation_block.call(mocka) if @expectation_block
            end
          end

          class Condition < Expectation

          end

          class IfCondition < Expectation
            def setup(object)
              object.stubs(name).returns(true)
            end
          end

          class UnlessCondition < Expectation
            def setup(object)
              object.stubs(name).returns(false)
            end
          end

          def expects(method_name, &blk)
            @expectations ||= []
            @expectations << Expects.new(method_name, &blk)
            self
          end

          def stubs(method_name, &blk)
            @expectations ||= []
            @expectations << Stubs.new(method_name, &blk)
            self
          end

          def if(condition)
            @expectations ||= []
            @expectations << IfCondition.new(condition)
            self
          end

          def unless(condition)
            @expectations ||= []
            @expectations << UnlessCondition.new(condition)
            self
          end

          def restubs(object, *without)
            without = [without].flatten
            s_m = object.class.current_state_machine
            stub_methods = (after_transition_methods(s_m) | if_and_unless_conditions(s_m)).uniq - without
            object.reset_mocha
            stub_methods.each do |m|
              object.stubs(m)
            end
          end

          def after_transition_methods(s_m)
            s_m.callbacks.values.flatten.map { |c| c.instance_variable_get(:@methods) }.flatten.select { |m| m.is_a?(Symbol) }
          end

          def if_and_unless_conditions(s_m)
            branches = s_m.events.map(&:branches).flatten
            branches.map(&:if_condition).compact | branches.map(&:unless_condition).compact
          end

          def verify
            event, from, to = @event, @from, @to
            expectations = @expectations || []
            helper = self
            @context.it(description) do
              helper.restubs(subject, expectations.map(&:name))
              expectations.each do |expectation|
                expectation.setup(subject)
              end
              state_field = defined?(call_center_state_field) ? call_center_state_field.to_sym : :state
              subject.send(:"#{state_field}=", from)
              subject.send(:"#{event}!")
              subject.send(state_field).must_equal(to)
            end
          end

          private

          def description
            "should flow on ##{@event}! from :#{@from} to :#{@to}"
          end
        end

        class ItShouldRender < ItShouldFlow
          def is(state)
            @state = state
            self
          end

          class Assertion
            def initialize(*args)
              @args = args
            end

            def setup(context)
              context.assert_select(*@args)
            end
          end

          def selects(selector, matcher = nil)
            @assertions ||= []
            @assertions << Assertion.new(selector, matcher)
            self
          end

          def verify
            state = @state
            expectations = @expectations || []
            assertions = @assertions || []
            helper = self
            @context.it(description) do
              helper.restubs(subject, expectations.map(&:name))
              expectations.each do |expectation|
                expectation.setup(subject)
              end
              state_field = defined?(call_center_state_field) ? call_center_state_field.to_sym : :state
              subject.send(:"#{state_field}=", state)
              body(subject.render)
              assertions.each do |assertion|
                assertion.setup(self)
              end
            end
          end

          private

          def description
            "should render when :#{@state}"
          end
        end

        if defined?(::MiniTest::Spec)
          ::MiniTest::Spec.class_eval do
            include ActionController::Assertions::SelectorAssertions

            def self.it_should_flow(&block)
              CallCenter::Test::MiniTest::DSL::ItShouldFlow.new(self, &block).verify
            end

            def self.it_should_render(&block)
              CallCenter::Test::MiniTest::DSL::ItShouldRender.new(self, &block).verify
            end

            def stub_branches(object)
              CallCenter::Test::MiniTest::DSL::ItShouldFlow.new(self).restubs(object)
            end

            def response_from_page_or_rjs
              HTML::Document.new(@_body).root
            end

            def body(text, debug = false)
              puts text if debug
              @_body = text
            end

            private

            def build_message(head, template=nil, *arguments)
              template &&= template.chomp
              return ::Test::Unit::Assertions::AssertionMessage.new(head, template, arguments)
            end
          end
        end
      end
    end
  end
end
