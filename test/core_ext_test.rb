require 'helper'

class MyObject

end

class CoreExtTest < Test::Unit::TestCase
  should "use existing" do
    obj = MyObject.new
    $capture = nil
    block = lambda { |a|
      $capture = [self, a]
    }
    obj.instance_exec(true, &block)

    assert_equal [obj, true], $capture
  end
end
