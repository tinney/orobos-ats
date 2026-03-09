# frozen_string_literal: true

class CreateInterviewParticipants < ActiveRecord::Migration[8.1]
  def change
    create_table :interview_participants, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :interview, type: :uuid, null: false, foreign_key: {on_delete: :cascade}
      t.references :user, type: :uuid, null: false, foreign_key: {on_delete: :cascade}

      t.timestamps
    end

    add_index :interview_participants, [:interview_id, :user_id], unique: true, name: "index_interview_participants_on_interview_and_user"
  end
end
