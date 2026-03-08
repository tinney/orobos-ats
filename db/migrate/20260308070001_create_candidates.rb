# frozen_string_literal: true

class CreateCandidates < ActiveRecord::Migration[8.1]
  def change
    create_table :candidates, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false

      t.timestamps
    end

    add_index :candidates, [:company_id, :email], unique: true
    add_index :candidates, :email
  end
end
