# frozen_string_literal: true

class CreateInterviews < ActiveRecord::Migration[8.1]
  def change
    create_table :interviews, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :application, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :interview_phase, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.datetime :scheduled_at

      t.timestamps
    end

    # One interview event per phase per application
    add_index :interviews, [:application_id, :interview_phase_id], unique: true, name: "index_interviews_on_application_and_phase"
  end
end
