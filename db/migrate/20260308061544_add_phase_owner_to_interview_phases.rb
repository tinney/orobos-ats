class AddPhaseOwnerToInterviewPhases < ActiveRecord::Migration[8.1]
  def change
    add_column :interview_phases, :phase_owner_id, :uuid
    add_index :interview_phases, :phase_owner_id
    add_foreign_key :interview_phases, :users, column: :phase_owner_id, on_delete: :nullify
  end
end
