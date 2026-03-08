class CreateInterviewPhases < ActiveRecord::Migration[8.1]
  def change
    create_table :interview_phases, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :company, null: false, foreign_key: true, type: :uuid
      t.references :role, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :interview_phases, [:role_id, :position]
    add_index :interview_phases, [:role_id, :name], unique: true
  end
end
