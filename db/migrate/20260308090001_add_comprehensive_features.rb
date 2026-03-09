class AddComprehensiveFeatures < ActiveRecord::Migration[8.1]
  def change
    # Custom questions per role
    create_table :custom_questions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :role, type: :uuid, null: false, foreign_key: true
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.string :label, null: false
      t.string :field_type, null: false, default: "text" # text, textarea, select
      t.boolean :required, null: false, default: false
      t.jsonb :options, default: [] # for select-type questions
      t.integer :position, null: false, default: 0
      t.timestamps
      t.index [:role_id, :position]
    end

    # Snapshot of custom questions at application time
    create_table :question_snapshots, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :application_id, null: false
      t.uuid :custom_question_id
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.string :label, null: false
      t.string :field_type, null: false
      t.boolean :required, null: false, default: false
      t.jsonb :options, default: []
      t.text :answer
      t.timestamps
      t.index :application_id, name: "idx_question_snapshots_on_app_id"
      t.index :custom_question_id, name: "idx_question_snapshots_on_cq_id"
    end
    add_foreign_key :question_snapshots, :applications, column: :application_id, on_delete: :cascade
    add_foreign_key :question_snapshots, :custom_questions, column: :custom_question_id, on_delete: :nullify

    # Bot detection fields on applications
    add_column :applications, :bot_score, :integer, default: 0
    add_column :applications, :bot_flagged, :boolean, default: false
    add_column :applications, :bot_reasons, :jsonb, default: []
    add_column :applications, :bot_dismissed, :boolean, default: false
    add_column :applications, :submission_duration_ms, :integer
    add_column :applications, :honeypot_filled, :boolean, default: false
    add_column :applications, :submitted_at, :datetime
    add_column :applications, :form_loaded_at, :datetime

    # Pipeline fields
    add_column :applications, :previous_status, :string
    add_column :applications, :rejection_reason, :string
    add_column :applications, :withdrawal_reason, :string
    add_column :applications, :current_interview_phase_id, :uuid
    add_index :applications, :current_interview_phase_id, name: "idx_apps_current_phase"
    add_column :applications, :transferred_from_role_id, :uuid
    add_column :applications, :transferred_at, :datetime
    add_index :applications, :bot_flagged, name: "idx_apps_bot_flagged"

    # Transfer markers (lightweight record in source role)
    create_table :transfer_markers, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :source_role, type: :uuid, null: false, foreign_key: {to_table: :roles}
      t.references :target_role, type: :uuid, null: false, foreign_key: {to_table: :roles}
      t.references :candidate, type: :uuid, null: false, foreign_key: true
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.uuid :target_application_id
      t.datetime :transferred_at, null: false
      t.timestamps
      t.index [:source_role_id, :candidate_id]
    end
    add_foreign_key :transfer_markers, :applications, column: :target_application_id, on_delete: :nullify

    # Interview status field
    add_column :interviews, :status, :string, default: "unscheduled", null: false
    add_index :interviews, :status, name: "idx_interviews_status"

    # Scorecards
    create_table :scorecards, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :interview, type: :uuid, null: false, foreign_key: {on_delete: :cascade}
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.text :notes
      t.boolean :submitted, null: false, default: false
      t.timestamps
      t.index [:interview_id, :user_id], unique: true
    end

    # Scorecard categories (named ratings 1-5)
    create_table :scorecard_categories, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :scorecard, type: :uuid, null: false, foreign_key: {on_delete: :cascade}
      t.string :name, null: false
      t.integer :rating, null: false
      t.timestamps
      t.index [:scorecard_id, :name], unique: true
    end

    # Offers
    create_table :offers, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :offer_application_id, null: false
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.references :created_by, type: :uuid, null: false, foreign_key: {to_table: :users}
      t.decimal :salary, precision: 12, scale: 2
      t.string :salary_currency, default: "USD"
      t.date :start_date
      t.string :status, null: false, default: "pending"
      t.text :notes
      t.integer :revision, null: false, default: 1
      t.timestamps
      t.index :offer_application_id, name: "idx_offers_on_app_id"
    end
    add_foreign_key :offers, :applications, column: :offer_application_id, on_delete: :cascade

    # Offer revisions (history)
    create_table :offer_revisions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :offer, type: :uuid, null: false, foreign_key: {on_delete: :cascade}
      t.decimal :salary, precision: 12, scale: 2
      t.string :salary_currency
      t.date :start_date
      t.string :status
      t.text :notes
      t.integer :revision_number, null: false
      t.references :changed_by, type: :uuid, null: true, foreign_key: {to_table: :users}
      t.timestamps
    end

    # Rate limiting table
    create_table :rate_limits, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :key, null: false
      t.integer :count, null: false, default: 0
      t.datetime :window_start, null: false
      t.timestamps
      t.index [:key, :window_start], unique: true
    end

    # Add hiring_manager_id to roles
    add_reference :roles, :hiring_manager, type: :uuid, foreign_key: {to_table: :users}, null: true

    # Add description to companies
    add_column :companies, :description, :text
  end
end
