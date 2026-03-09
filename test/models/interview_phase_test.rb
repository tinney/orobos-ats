require "test_helper"

class InterviewPhaseTest < ActiveSupport::TestCase
  setup do
    @company = Company.create!(name: "Test Corp", subdomain: "testcorp-ip")
    ActsAsTenant.current_tenant = @company
    # Create role without default phases callback to test phases independently
    @role = Role.create!(company: @company, title: "Software Engineer")
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  # --- Validations ---

  test "valid interview phase" do
    phase = @role.interview_phases.first
    assert phase.valid?
  end

  test "requires name" do
    phase = InterviewPhase.new(role: @role, company: @company, position: 0)
    assert_not phase.valid?
    assert_includes phase.errors[:name], "can't be blank"
  end

  test "position auto-assigns to next available on create when not specified" do
    phase = InterviewPhase.new(role: @role, company: @company, name: "Custom Phase")
    assert phase.valid?
    assert phase.position >= 0
  end

  test "position validates as non-negative integer on update" do
    phase = @role.interview_phases.first
    phase.position = -1
    assert_not phase.valid?
    assert phase.errors[:position].any?
  end

  test "name must be unique within a role" do
    existing_name = @role.interview_phases.first.name
    phase = InterviewPhase.new(role: @role, company: @company, name: existing_name, position: 99)
    assert_not phase.valid?
    assert phase.errors[:name].any?
  end

  test "same name can exist in different roles" do
    other_role = Role.create!(company: @company, title: "Designer")
    # Both roles have default phases with same names; that's fine since they're different roles
    assert other_role.interview_phases.where(name: "Phone Screen").exists?
    assert @role.interview_phases.where(name: "Phone Screen").exists?
  end

  # --- Associations ---

  test "belongs to role" do
    phase = @role.interview_phases.first
    assert_equal @role, phase.role
  end

  test "belongs to company" do
    phase = @role.interview_phases.first
    assert_equal @company, phase.company
  end

  # --- Default phases seeded on role creation ---

  test "creating a role seeds default interview phases" do
    role = Role.create!(company: @company, title: "New Role")
    phases = role.interview_phases.ordered

    assert_equal InterviewPhase::DEFAULT_PHASES.length, phases.count
    InterviewPhase::DEFAULT_PHASES.each_with_index do |name, index|
      assert_equal name, phases[index].name
      assert_equal index, phases[index].position
    end
  end

  test "default phases are in correct order" do
    phases = @role.interview_phases.ordered
    assert_equal "Phone Screen", phases[0].name
    assert_equal "Technical Interview", phases[1].name
    assert_equal "Onsite Interview", phases[2].name
    assert_equal "Final Interview", phases[3].name
  end

  # --- Ordering ---

  test "ordered scope returns phases by position" do
    phases = @role.interview_phases.ordered
    positions = phases.map(&:position)
    assert_equal positions.sort, positions
  end

  test "set_default_position assigns next position on create" do
    max_pos = @role.interview_phases.maximum(:position)
    new_phase = @role.interview_phases.create!(name: "Custom Phase", company: @company)
    assert_equal max_pos + 1, new_phase.position
  end

  test "move_to reorders phases" do
    phases = @role.interview_phases.ordered.to_a
    # Move the last phase to position 0
    last_phase = phases.last
    last_phase.move_to(0)

    reordered = @role.interview_phases.ordered.to_a
    assert_equal last_phase.id, reordered.first.id
    assert_equal 0, reordered.first.position
  end

  # --- Tenant scoping ---

  test "interview phases are scoped to current tenant" do
    other_company = Company.create!(name: "Other Corp", subdomain: "othercorp-ip")
    ActsAsTenant.with_tenant(other_company) do
      other_role = Role.create!(company: other_company, title: "Other Role")
      # Should only see phases from other_company
      assert_equal other_role.interview_phases.count, InterviewPhase.count
    end

    # Original tenant should not see the other company's phases
    assert_equal @role.interview_phases.count, InterviewPhase.count
  end

  # --- Destroying role cascades to phases ---

  test "destroying role destroys its interview phases" do
    phase_ids = @role.interview_phases.pluck(:id)
    assert phase_ids.any?

    @role.destroy!
    assert_equal 0, InterviewPhase.where(id: phase_ids).count
  end

  # --- DEFAULT_PHASES constant ---

  test "DEFAULT_PHASES contains expected phases" do
    expected = ["Phone Screen", "Technical Interview", "Onsite Interview", "Final Interview"]
    assert_equal expected, InterviewPhase::DEFAULT_PHASES
  end

  # --- Phase versioning / snapshotting ---

  test "new phase defaults to version 1" do
    phase = @role.interview_phases.first
    assert_equal 1, phase.phase_version
  end

  test "phase starts as active (not archived)" do
    phase = @role.interview_phases.first
    assert phase.active?
    assert_not phase.archived?
    assert_nil phase.archived_at
  end

  test "archive! sets archived_at timestamp" do
    phase = @role.interview_phases.first
    phase.archive!
    assert phase.archived?
    assert_not phase.active?
    assert_not_nil phase.archived_at
  end

  test "active scope excludes archived phases" do
    phases = @role.interview_phases.to_a
    phases.first.archive!

    active = @role.interview_phases.active
    assert_not_includes active, phases.first
    assert_equal phases.size - 1, active.count
  end

  test "archived scope includes only archived phases" do
    phases = @role.interview_phases.to_a
    phases.first.archive!

    archived = @role.interview_phases.archived
    assert_equal 1, archived.count
    assert_includes archived, phases.first
  end

  test "active_interview_phases on role returns only active phases" do
    phases = @role.interview_phases.to_a
    phases.first.archive!

    active = @role.active_interview_phases
    assert_not_includes active, phases.first
  end

  test "archived phases can share name with active phases" do
    phase = @role.interview_phases.find_by(name: "Phone Screen")
    phase.archive!

    new_phase = InterviewPhase.new(
      name: "Phone Screen",
      position: 0,
      role: @role,
      company: @company
    )
    assert new_phase.valid?, "Archived phase should not block active phase with same name"
  end

  # --- create_new_version ---

  test "create_new_version archives old phase and creates new one" do
    phase = @role.interview_phases.find_by(name: "Phone Screen")
    original_id = phase.id
    original_position = phase.position

    new_phase = phase.create_new_version(name: "Updated Phone Screen")

    assert phase.reload.archived?
    assert new_phase.active?
    assert_equal "Updated Phone Screen", new_phase.name
    assert_equal original_position, new_phase.position
    assert_equal phase.role_id, new_phase.role_id
    assert_equal phase.company_id, new_phase.company_id
    assert_equal original_id, new_phase.original_phase_id
    assert_equal 2, new_phase.phase_version
  end

  test "create_new_version preserves original position by default" do
    phase = @role.interview_phases.find_by(name: "Technical Interview")
    original_position = phase.position

    new_phase = phase.create_new_version(name: "Updated Technical")
    assert_equal original_position, new_phase.position
  end

  test "create_new_version can override position" do
    phase = @role.interview_phases.first
    new_phase = phase.create_new_version(name: "New Name", position: 99)
    assert_equal 99, new_phase.position
  end

  test "create_new_version increments version number across lineage" do
    phase = @role.interview_phases.find_by(name: "Phone Screen")

    v2 = phase.create_new_version(name: "V2 Phone Screen")
    assert_equal 2, v2.phase_version

    v3 = v2.create_new_version(name: "V3 Phone Screen")
    assert_equal 3, v3.phase_version
  end

  test "create_new_version uses root phase id for lineage tracking" do
    phase = @role.interview_phases.find_by(name: "Phone Screen")
    root_id = phase.id

    v2 = phase.create_new_version(name: "V2")
    assert_equal root_id, v2.original_phase_id

    v3 = v2.create_new_version(name: "V3")
    assert_equal root_id, v3.original_phase_id
  end

  test "create_new_version with no attribute changes preserves name" do
    phase = @role.interview_phases.first
    new_phase = phase.create_new_version
    assert_equal phase.name, new_phase.name
    assert_equal 2, new_phase.phase_version
  end

  # --- update_with_versioning ---

  test "update_with_versioning updates in place when no candidate data" do
    phase = @role.interview_phases.find_by(name: "Phone Screen")

    result = phase.update_with_versioning(name: "Updated Phone Screen")
    assert_equal phase, result
    assert_equal "Updated Phone Screen", phase.reload.name
    assert phase.active?
  end

  test "update_with_versioning does not create new record when no candidate data" do
    phase = @role.interview_phases.first
    assert_no_difference "InterviewPhase.count" do
      phase.update_with_versioning(name: "Updated")
    end
  end

  # --- Historical data preservation ---

  test "archived phase retains original name after new version created" do
    phase = @role.interview_phases.find_by(name: "Phone Screen")
    original_name = phase.name

    phase.create_new_version(name: "Renamed Phase")

    assert_equal original_name, phase.reload.name
    assert phase.archived?
  end

  test "archived phase retains original position after new version" do
    phase = @role.interview_phases.find_by(name: "Phone Screen")
    original_position = phase.position

    phase.create_new_version(name: "Renamed Phase", position: 99)

    assert_equal original_position, phase.reload.position
  end

  test "multiple phases can be versioned independently" do
    phase1 = @role.interview_phases.find_by(name: "Phone Screen")
    phase2 = @role.interview_phases.find_by(name: "Technical Interview")

    phase1.create_new_version(name: "Updated Phone Screen")
    phase2.create_new_version(name: "Updated Technical")

    active_names = @role.active_interview_phases.pluck(:name)
    assert_includes active_names, "Updated Phone Screen"
    assert_includes active_names, "Updated Technical"
    assert_not_includes active_names, "Phone Screen"
    assert_not_includes active_names, "Technical Interview"
  end

  # --- version_history ---

  test "version_history returns all versions in lineage order" do
    phase = @role.interview_phases.find_by(name: "Phone Screen")
    v2 = phase.create_new_version(name: "V2")
    v3 = v2.create_new_version(name: "V3")

    history = v3.version_history.to_a
    assert_equal 3, history.count
    assert_equal [1, 2, 3], history.map(&:phase_version)
  end

  test "version_history accessible from any version in lineage" do
    phase = @role.interview_phases.find_by(name: "Phone Screen")
    v2 = phase.create_new_version(name: "V2")
    v3 = v2.create_new_version(name: "V3")

    # All three versions should return the same lineage
    assert_equal phase.version_history.pluck(:id).sort, v2.version_history.pluck(:id).sort
    assert_equal v2.version_history.pluck(:id).sort, v3.version_history.pluck(:id).sort
  end

  # --- move_to with archived phases ---

  test "move_to only considers active phases when reordering" do
    @role.interview_phases.destroy_all

    p1 = InterviewPhase.create!(name: "Phase A", position: 0, role: @role, company: @company)
    p2 = InterviewPhase.create!(name: "Phase B", position: 1, role: @role, company: @company)
    archived = InterviewPhase.create!(name: "Archived Phase", position: 2, role: @role, company: @company)
    archived.archive!

    p2.move_to(0)
    assert_equal 0, p2.reload.position
    assert_equal 1, p1.reload.position
    # Archived phase position is unchanged
    assert_equal 2, archived.reload.position
  end

  # --- set_default_position with archived phases ---

  test "set_default_position ignores archived phases" do
    @role.interview_phases.each(&:archive!)

    new_phase = InterviewPhase.create!(
      name: "Fresh Phase",
      role: @role,
      company: @company
    )
    # Should get position 0 since no active phases exist
    assert_equal 0, new_phase.position
  end

  # --- move_to edge cases ---

  test "move_to clamps negative position to 0" do
    @role.interview_phases.destroy_all

    p1 = InterviewPhase.create!(name: "Phase A", position: 0, role: @role, company: @company)
    p2 = InterviewPhase.create!(name: "Phase B", position: 1, role: @role, company: @company)
    p3 = InterviewPhase.create!(name: "Phase C", position: 2, role: @role, company: @company)

    p3.move_to(-5)
    assert_equal 0, p3.reload.position
    assert_equal 1, p1.reload.position
    assert_equal 2, p2.reload.position
  end

  test "move_to clamps position beyond max to last position" do
    @role.interview_phases.destroy_all

    p1 = InterviewPhase.create!(name: "Phase A", position: 0, role: @role, company: @company)
    p2 = InterviewPhase.create!(name: "Phase B", position: 1, role: @role, company: @company)
    p3 = InterviewPhase.create!(name: "Phase C", position: 2, role: @role, company: @company)

    p1.move_to(100)
    assert_equal 2, p1.reload.position
    assert_equal 0, p2.reload.position
    assert_equal 1, p3.reload.position
  end

  test "move_to handles single phase" do
    @role.interview_phases.destroy_all

    p1 = InterviewPhase.create!(name: "Only Phase", position: 0, role: @role, company: @company)
    p1.move_to(0) # no-op
    assert_equal 0, p1.reload.position
  end

  # --- recompact_positions! ---

  test "recompact_positions! closes gaps after deletion" do
    @role.interview_phases.destroy_all

    p1 = InterviewPhase.create!(name: "Phase A", position: 0, role: @role, company: @company)
    _p2 = InterviewPhase.create!(name: "Phase B", position: 1, role: @role, company: @company)
    p3 = InterviewPhase.create!(name: "Phase C", position: 2, role: @role, company: @company)

    _p2.destroy!
    InterviewPhase.recompact_positions!(@role)

    assert_equal 0, p1.reload.position
    assert_equal 1, p3.reload.position
  end

  test "recompact_positions! ignores archived phases" do
    @role.interview_phases.destroy_all

    p1 = InterviewPhase.create!(name: "Phase A", position: 0, role: @role, company: @company)
    p2 = InterviewPhase.create!(name: "Phase B", position: 1, role: @role, company: @company)
    p3 = InterviewPhase.create!(name: "Phase C", position: 2, role: @role, company: @company)

    p2.archive!
    InterviewPhase.recompact_positions!(@role)

    assert_equal 0, p1.reload.position
    assert_equal 1, p2.reload.position # archived, unchanged
    assert_equal 1, p3.reload.position # recompacted from 2 to 1
  end

  test "positions remain contiguous after multiple operations" do
    @role.interview_phases.destroy_all

    phases = 5.times.map do |i|
      InterviewPhase.create!(name: "Phase #{i}", role: @role, company: @company)
    end

    # Move phase 4 to position 1
    phases[4].move_to(1)
    positions = @role.interview_phases.active.ordered.pluck(:position)
    assert_equal [0, 1, 2, 3, 4], positions

    # Move phase at position 0 to position 3
    first = @role.interview_phases.active.ordered.first
    first.move_to(3)
    positions = @role.interview_phases.active.ordered.pluck(:position)
    assert_equal [0, 1, 2, 3, 4], positions
  end

  # --- Edge cases ---

  test "destroying original phase nullifies version references" do
    phase = @role.interview_phases.find_by(name: "Phone Screen")
    v2 = phase.create_new_version(name: "V2")
    assert_equal phase.id, v2.original_phase_id

    phase.destroy!
    assert_nil v2.reload.original_phase_id
  end

  test "versioning works in a transaction - all or nothing" do
    phase = @role.interview_phases.find_by(name: "Phone Screen")
    count_before = InterviewPhase.count

    # Simulate a failure by trying to create with invalid data
    begin
      phase.transaction do
        phase.create_new_version(name: nil) # should fail validation
      end
    rescue ActiveRecord::RecordInvalid
      # Expected
    end

    # Original phase should not be archived on failure
    assert phase.reload.active?
    assert_equal count_before, InterviewPhase.count
  end
end
