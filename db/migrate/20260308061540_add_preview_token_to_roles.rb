class AddPreviewTokenToRoles < ActiveRecord::Migration[8.1]
  def change
    add_column :roles, :preview_token, :string
    add_index :roles, :preview_token, unique: true, where: "preview_token IS NOT NULL"
  end
end
