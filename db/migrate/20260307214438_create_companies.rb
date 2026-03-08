class CreateCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :companies, id: :uuid do |t|
      t.string :name, null: false
      t.string :subdomain, null: false
      t.string :primary_color, default: "#4F46E5"
      t.timestamps
    end

    add_index :companies, :subdomain, unique: true
    add_index :companies, :name
  end
end
