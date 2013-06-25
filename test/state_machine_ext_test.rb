require File.expand_path("../helper", __FILE__)

class MachineAfterBeingDuplicatedTest < Test::Unit::TestCase
  def setup
    @machine = StateMachine::Machine.new(Class.new, :state, :initial => :parked)
    @machine.event(:ignite) {}
    @machine.before_transition(lambda {})
    @machine.after_transition(lambda {})
    @machine.around_transition(lambda {})
    @machine.after_failure(lambda {})

    @new_class = Class.new

    @copied_machine = @machine.duplicate_to(@new_class)
  end

  def test_should_copy_each_event_and_add_actions
    @new_instance = @new_class.new
    assert @new_instance.respond_to?(:ignite)
    assert @new_instance.respond_to?(:ignite!)
  end

  def test_should_copy_each_event_and_add_predicate
    @new_instance = @new_class.new
    assert @new_instance.respond_to?(:parked?)
  end

  def test_should_not_have_the_same_collection_of_states
    assert_not_same @copied_machine.states, @machine.states
  end

  def test_should_copy_each_state
    assert_not_same @copied_machine.states[:parked], @machine.states[:parked]
  end

  def test_should_update_machine_for_each_state
    assert_equal @copied_machine, @copied_machine.states[:parked].machine
  end

  def test_should_not_update_machine_for_original_state
    assert_equal @machine, @machine.states[:parked].machine
  end

  def test_should_not_have_the_same_collection_of_events
    assert_not_same @copied_machine.events, @machine.events
  end

  def test_should_copy_each_event
    assert_not_same @copied_machine.events[:ignite], @machine.events[:ignite]
  end

  def test_should_update_machine_for_each_event
    assert_equal @copied_machine, @copied_machine.events[:ignite].machine
  end

  def test_should_not_update_machine_for_original_event
    assert_equal @machine, @machine.events[:ignite].machine
  end

  def test_should_not_have_the_same_callbacks
    assert_not_same @copied_machine.callbacks, @machine.callbacks
  end

  def test_should_not_have_the_same_before_callbacks
    assert_not_same @copied_machine.callbacks[:before], @machine.callbacks[:before]
  end

  def test_should_not_have_the_same_after_callbacks
    assert_not_same @copied_machine.callbacks[:after], @machine.callbacks[:after]
  end

  def test_should_not_have_the_same_failure_callbacks
    assert_not_same @copied_machine.callbacks[:failure], @machine.callbacks[:failure]
  end
end
