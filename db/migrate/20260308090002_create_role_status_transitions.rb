class CreateRoleStatusTransitions < ActiveRecord::Migration[8.1]
  def change
    create_table :role_status_transitions, id: :uuid do |t|
      t.uuid :role_id, null: false
      t.uuid :company_id, null: false
      t.string :from_status, null: false
      t.string :to_status, null: false
      t.uuid :user_id

      t.timestamps
    end

    add_index :role_status_transitions, :role_id
    add_index :role_status_transitions, :company_id
    add_index :role_status_transitions, [:role_id, :created_at], name: "idx_role_transitions_role_created"
    add_foreign_key :role_status_transitions, :roles, on_delete: :cascade
    add_foreign_key :role_status_transitions, :companies
    add_foreign_key :role_status_transitions, :users, on_delete: :nullify
  end
end
