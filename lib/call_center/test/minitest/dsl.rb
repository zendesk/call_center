require 'action_pack/version'

if ActionPack::VERSION::MAJOR == 2
  require 'action_controller/assertions/selector_assertions'
else
  require 'action_dispatch/testing/assertions/selector'
  require 'active_support/core_ext/class/attribute_accessors' # do not blow up with undefined method cattr_accessor
  require 'active_support/core_ext/string/encoding' # do not blow up with undefined method encoding_aware?
end
require 'action_controller/vendor/html-scanner'
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
              if m.instance_of?(CallCenter::ConditionalStack::Evaluator)
                m.stack.map(&:name).each do |name|
                  object.stubs(name)
                end
              else
                object.stubs(m)
              end
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
              helper.verify_send(subject, event, state_field, to)
              if subject.respond_to?(:call_flow_run_deferred)
                subject.call_flow_run_deferred(:before_transition)
                subject.call_flow_run_deferred(:after_transition)
                subject.call_flow_run_deferred(:after_failure)
              end
            end
          end

          def send_event(subject, event)
            subject.send(:"#{event}!")
          end

          def verify_send(subject, event, state_field, to)
            send_event(subject, event)
            subject.send(state_field).must_equal(to)
          end

          private

          def description
            "should flow on ##{@event}! from :#{@from} to :#{@to}"
          end
        end

        class ItShouldNotFlow < ItShouldFlow
          def send_event(subject, event)
            subject.send(:"#{event}")
          end

          def verify_send(subject, event, state_field, to)
            send_event(subject, event).wont_equal(true)
          end

          private

          def description
            "should not flow on ##{@event}! from :#{@from}"
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
            if ActionPack::VERSION::MAJOR == 2
              include ActionController::Assertions::SelectorAssertions
            else
              include ActionDispatch::Assertions::SelectorAssertions
            end

            def self.it_should_flow(&block)
              CallCenter::Test::MiniTest::DSL::ItShouldFlow.new(self, &block).verify
            end

            def self.it_should_not_flow(&block)
              CallCenter::Test::MiniTest::DSL::ItShouldNotFlow.new(self, &block).verify
            end

            def self.it_should_render(&block)
              CallCenter::Test::MiniTest::DSL::ItShouldRender.new(self, &block).verify
            end

            def stub_branches(object)
              CallCenter::Test::MiniTest::DSL::ItShouldFlow.new(self).restubs(object)
            end

            def response_from_page_or_rjs
              html_document.root
            end

            def body(text, debug = false)
              puts text if debug
              @_body = text
            end

            def html_document
              HTML::Document.new(@_body)
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
