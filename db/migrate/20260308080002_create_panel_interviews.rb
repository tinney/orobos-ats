class CreatePanelInterviews < ActiveRecord::Migration[8.1]
  def change
    create_table :panel_interviews, id: :uuid do |t|
      t.references :interview, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, type: :uuid

      t.timestamps
    end

    add_index :panel_interviews, [:interview_id, :user_id], unique: true, name: "index_panel_interviews_on_interview_and_user"
  end
end
