# frozen_string_literal: true

class CreateApplications < ActiveRecord::Migration[8.1]
  def change
    create_table :applications, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: {on_delete: :cascade}
      t.references :candidate, type: :uuid, null: false, foreign_key: {on_delete: :cascade}
      t.references :role, type: :uuid, null: false, foreign_key: {on_delete: :cascade}
      t.string :status, null: false, default: "applied"

      t.timestamps
    end

    add_index :applications, [:candidate_id, :role_id], unique: true
    add_index :applications, [:company_id, :status]
  end
end
