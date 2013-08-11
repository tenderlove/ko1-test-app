require 'test_helper'

class UserTest < ActiveSupport::TestCase
  def test_omg
    user = users(:aaron)
    assert user.valid_password? "password"
  end
end
