# frozen_string_literal: true

require "test_helper"

class Constraints::SubdomainConstraintTest < ActiveSupport::TestCase
  FakeRequest = Struct.new(:subdomain)

  setup do
    @constraint = Constraints::SubdomainConstraint.new
  end

  test "matches when subdomain is present" do
    assert @constraint.matches?(FakeRequest.new("acme"))
  end

  test "does not match when subdomain is blank" do
    refute @constraint.matches?(FakeRequest.new(""))
  end

  test "does not match when subdomain is nil" do
    refute @constraint.matches?(FakeRequest.new(nil))
  end

  test "does not match when subdomain is www" do
    refute @constraint.matches?(FakeRequest.new("www"))
  end

  test "matches case-insensitively" do
    assert @constraint.matches?(FakeRequest.new("ACME"))
  end
end
