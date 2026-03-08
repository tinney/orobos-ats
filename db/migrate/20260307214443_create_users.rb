class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: :uuid do |t|
      t.references :company, null: false, foreign_key: true, type: :uuid
      t.string :email, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :role, null: false, default: "interviewer"
      t.datetime :discarded_at
      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, [:company_id, :role]
    add_index :users, :discarded_at
  end
end
