class CreateTenants < ActiveRecord::Migration[8.1]
  def change
    create_table :tenants do |t|
      t.string :company_name, null: false
      t.string :subdomain, null: false
      t.string :slug, null: false
      t.string :admin_email, null: false
      t.string :primary_color, default: "#4F46E5"
      t.string :logo_url

      t.timestamps
    end

    add_index :tenants, :subdomain, unique: true
    add_index :tenants, :slug, unique: true
  end
end
