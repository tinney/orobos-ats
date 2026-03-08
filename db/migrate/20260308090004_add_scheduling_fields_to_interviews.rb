# frozen_string_literal: true

class AddSchedulingFieldsToInterviews < ActiveRecord::Migration[8.1]
  def change
    add_column :interviews, :duration_minutes, :integer, default: 60
    add_column :interviews, :location, :string
    add_column :interviews, :notes, :text
    add_column :interviews, :completed_at, :datetime
    add_column :interviews, :cancelled_at, :datetime
    add_column :interviews, :cancelled_reason, :string
  end
end
