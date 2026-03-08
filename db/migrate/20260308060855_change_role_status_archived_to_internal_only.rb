class ChangeRoleStatusArchivedToInternalOnly < ActiveRecord::Migration[8.1]
  def up
    execute <<-SQL
      UPDATE roles SET status = 'internal_only' WHERE status = 'archived'
    SQL
  end

  def down
    execute <<-SQL
      UPDATE roles SET status = 'archived' WHERE status = 'internal_only'
    SQL
  end
end
