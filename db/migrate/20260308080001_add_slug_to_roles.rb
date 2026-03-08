# frozen_string_literal: true

class AddSlugToRoles < ActiveRecord::Migration[8.1]
  def change
    add_column :roles, :slug, :string

    # Backfill existing roles with parameterized title slugs
    reversible do |dir|
      dir.up do
        execute <<-SQL.squish
          UPDATE roles SET slug = LOWER(REPLACE(REPLACE(REPLACE(TRIM(title), ' ', '-'), '.', ''), ',', ''))
          WHERE slug IS NULL
        SQL
      end
    end

    change_column_null :roles, :slug, false
    add_index :roles, [:company_id, :slug], unique: true
  end
end
