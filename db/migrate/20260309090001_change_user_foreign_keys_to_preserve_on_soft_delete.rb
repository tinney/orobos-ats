# frozen_string_literal: true

# Changes foreign key constraints on user references to preserve associated records
# when a user is soft-deleted (or even hard-deleted in edge cases).
#
# - interview_participants and panel_interviews: change from CASCADE to NULLIFY
#   so interview data is preserved even if user row is removed
# - scorecards: change from RESTRICT (default) to NULLIFY
# - offers (created_by_id): change from RESTRICT to NULLIFY
# - offer_revisions (changed_by_id): change from RESTRICT to NULLIFY
# - roles (hiring_manager_id): change from RESTRICT to NULLIFY
class ChangeUserForeignKeysToPreserveOnSoftDelete < ActiveRecord::Migration[8.1]
  def change
    # interview_participants: CASCADE -> NULLIFY
    remove_foreign_key :interview_participants, :users
    add_foreign_key :interview_participants, :users, on_delete: :nullify

    # panel_interviews: CASCADE -> NULLIFY
    remove_foreign_key :panel_interviews, :users
    add_foreign_key :panel_interviews, :users, on_delete: :nullify

    # scorecards: default (RESTRICT) -> NULLIFY
    remove_foreign_key :scorecards, :users
    add_foreign_key :scorecards, :users, on_delete: :nullify

    # offers: default (RESTRICT) -> NULLIFY on created_by_id
    remove_foreign_key :offers, column: :created_by_id
    add_foreign_key :offers, :users, column: :created_by_id, on_delete: :nullify

    # offer_revisions: default (RESTRICT) -> NULLIFY on changed_by_id
    remove_foreign_key :offer_revisions, column: :changed_by_id
    add_foreign_key :offer_revisions, :users, column: :changed_by_id, on_delete: :nullify

    # roles: default (RESTRICT) -> NULLIFY on hiring_manager_id
    remove_foreign_key :roles, column: :hiring_manager_id
    add_foreign_key :roles, :users, column: :hiring_manager_id, on_delete: :nullify

    # role_status_transitions already has on_delete: :nullify — no change needed
  end
end
