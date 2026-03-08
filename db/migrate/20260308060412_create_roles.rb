class CreateRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :roles, id: :uuid do |t|
      t.references :company, null: false, foreign_key: true, type: :uuid
      t.string :title, null: false
      t.text :description
      t.string :location
      t.boolean :remote, default: false, null: false
      t.integer :salary_min
      t.integer :salary_max
      t.string :salary_currency, default: "USD"
      t.string :status, default: "draft", null: false
      t.timestamps
    end

    add_index :roles, [:company_id, :status]
    add_index :roles, [:company_id, :title]
  end
end
