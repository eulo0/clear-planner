require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "new users default to needing onboarding (onboard_status true)" do
    assert User.new.onboard_status, "expected a brand-new User to default onboard_status to true"
  end
end
