class AddVersioningToInterviewPhases < ActiveRecord::Migration[8.1]
  def change
    add_column :interview_phases, :archived_at, :datetime
    add_column :interview_phases, :original_phase_id, :uuid
    add_column :interview_phases, :phase_version, :integer, null: false, default: 1

    add_index :interview_phases, :archived_at
    add_index :interview_phases, :original_phase_id
    add_foreign_key :interview_phases, :interview_phases, column: :original_phase_id, on_delete: :nullify

    # Remove the unique constraint on [role_id, name] since archived phases
    # can share names with active phases
    remove_index :interview_phases, [:role_id, :name]
    # Add a unique constraint only for active (non-archived) phases
    add_index :interview_phases, [:role_id, :name],
              unique: true,
              where: "archived_at IS NULL",
              name: "index_interview_phases_active_unique_name"
  end
end
