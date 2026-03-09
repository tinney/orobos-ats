# frozen_string_literal: true

# Corrects FK behavior for user references on NOT NULL columns.
# These columns cannot be nullified, so we use RESTRICT instead
# to prevent accidental hard deletion of users with associated data.
# Users should only ever be soft-deleted (discarded_at set).
#
# Nullable columns (hiring_manager_id, changed_by_id, phase_owner_id)
# correctly remain on_delete: :nullify.
class FixUserFkRestrictForNonNullableColumns < ActiveRecord::Migration[8.1]
  def change
    # interview_participants.user_id is NOT NULL → use RESTRICT
    remove_foreign_key :interview_participants, :users
    add_foreign_key :interview_participants, :users, on_delete: :restrict

    # panel_interviews.user_id is NOT NULL → use RESTRICT
    remove_foreign_key :panel_interviews, :users
    add_foreign_key :panel_interviews, :users, on_delete: :restrict

    # scorecards.user_id is NOT NULL → use RESTRICT
    remove_foreign_key :scorecards, :users
    add_foreign_key :scorecards, :users, on_delete: :restrict

    # offers.created_by_id is NOT NULL → use RESTRICT
    remove_foreign_key :offers, column: :created_by_id
    add_foreign_key :offers, :users, column: :created_by_id, on_delete: :restrict
  end
end
