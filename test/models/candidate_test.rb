# frozen_string_literal: true

require "test_helper"

class CandidateTest < ActiveSupport::TestCase
  setup do
    @company = Company.create!(name: "Test Co", subdomain: "testco")
    ActsAsTenant.current_tenant = @company
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "valid candidate" do
    candidate = Candidate.new(
      company: @company,
      first_name: "Jane",
      last_name: "Doe",
      email: "jane@example.com"
    )
    assert candidate.valid?
  end

  test "requires first_name" do
    candidate = Candidate.new(company: @company, last_name: "Doe", email: "jane@example.com")
    assert_not candidate.valid?
    assert_includes candidate.errors[:first_name], "can't be blank"
  end

  test "requires last_name" do
    candidate = Candidate.new(company: @company, first_name: "Jane", email: "jane@example.com")
    assert_not candidate.valid?
    assert_includes candidate.errors[:last_name], "can't be blank"
  end

  test "requires email" do
    candidate = Candidate.new(company: @company, first_name: "Jane", last_name: "Doe")
    assert_not candidate.valid?
    assert_includes candidate.errors[:email], "can't be blank"
  end

  test "normalizes email to lowercase" do
    candidate = Candidate.create!(
      company: @company,
      first_name: "Jane",
      last_name: "Doe",
      email: "JANE@Example.COM"
    )
    assert_equal "jane@example.com", candidate.email
  end

  test "email unique within company" do
    Candidate.create!(company: @company, first_name: "Jane", last_name: "Doe", email: "jane@example.com")
    dup = Candidate.new(company: @company, first_name: "Jane2", last_name: "Doe2", email: "jane@example.com")
    assert_not dup.valid?
    assert_includes dup.errors[:email], "has already been taken"
  end

  test "same email allowed in different companies" do
    other_company = Company.create!(name: "Other Co", subdomain: "otherco")
    Candidate.create!(company: @company, first_name: "Jane", last_name: "Doe", email: "jane@example.com")

    ActsAsTenant.current_tenant = other_company
    candidate = Candidate.new(company: other_company, first_name: "Jane", last_name: "Doe", email: "jane@example.com")
    assert candidate.valid?
  end

  test "full_name" do
    candidate = Candidate.new(first_name: "Jane", last_name: "Doe")
    assert_equal "Jane Doe", candidate.full_name
  end

  test "phone is optional" do
    candidate = Candidate.new(
      company: @company,
      first_name: "Jane",
      last_name: "Doe",
      email: "jane@example.com",
      phone: nil
    )
    assert candidate.valid?, "Candidate should be valid without phone"
  end

  test "phone accepts valid values" do
    candidate = Candidate.new(
      company: @company,
      first_name: "Jane",
      last_name: "Doe",
      email: "jane@example.com",
      phone: "+1-555-123-4567"
    )
    assert candidate.valid?
  end

  test "phone rejects values over 50 characters" do
    candidate = Candidate.new(
      company: @company,
      first_name: "Jane",
      last_name: "Doe",
      email: "jane@example.com",
      phone: "x" * 51
    )
    assert_not candidate.valid?
    assert_includes candidate.errors[:phone], "is too long (maximum is 50 characters)"
  end

  test "validates email format" do
    candidate = Candidate.new(
      company: @company,
      first_name: "Jane",
      last_name: "Doe",
      email: "not-an-email"
    )
    assert_not candidate.valid?
    assert candidate.errors[:email].any?
  end

  test "tenant scoping" do
    Candidate.create!(company: @company, first_name: "Jane", last_name: "Doe", email: "jane@example.com")
    other_company = Company.create!(name: "Other Co", subdomain: "otherco")
    ActsAsTenant.current_tenant = other_company
    assert_equal 0, Candidate.count
  end
end
