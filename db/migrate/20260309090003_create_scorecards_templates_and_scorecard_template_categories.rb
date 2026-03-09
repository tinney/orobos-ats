class CreateScorecardsTemplatesAndScorecardTemplateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :scorecards_templates, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :company, null: false, foreign_key: true, type: :uuid
      t.references :interview_phase, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.text :description

      t.timestamps
    end

    add_index :scorecards_templates, [:interview_phase_id, :name],
              unique: true,
              name: "index_scorecards_templates_on_phase_and_name"

    create_table :scorecard_template_categories, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :scorecards_template, null: false, type: :uuid,
                   foreign_key: { to_table: :scorecards_templates, on_delete: :cascade }
      t.string :name, null: false
      t.integer :rating_scale, null: false, default: 5
      t.integer :sort_order, null: false, default: 0

      t.timestamps
    end

    add_index :scorecard_template_categories, [:scorecards_template_id, :name],
              unique: true,
              name: "index_scorecard_tpl_categories_on_template_and_name"
    add_index :scorecard_template_categories, [:scorecards_template_id, :sort_order],
              name: "index_scorecard_tpl_categories_on_template_and_order"
  end
end
