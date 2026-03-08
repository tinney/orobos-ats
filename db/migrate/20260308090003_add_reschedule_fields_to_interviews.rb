# frozen_string_literal: true

class AddRescheduleFieldsToInterviews < ActiveRecord::Migration[8.1]
  def change
    add_column :interviews, :reschedule_count, :integer, default: 0, null: false
    add_column :interviews, :reschedule_reason, :string
    add_column :interviews, :schedule_history, :jsonb, default: [], null: false
  end
end
