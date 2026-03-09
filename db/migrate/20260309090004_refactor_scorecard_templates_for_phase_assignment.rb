class RefactorScorecardTemplatesForPhaseAssignment < ActiveRecord::Migration[8.1]
  def change
    # Remove the tight coupling of templates to interview phases.
    # Templates become company-level reusable resources.
    remove_index :scorecards_templates, name: "index_scorecards_templates_on_phase_and_name"
    remove_foreign_key :scorecards_templates, :interview_phases
    remove_reference :scorecards_templates, :interview_phase, type: :uuid

    # Add company-scoped unique name
    add_index :scorecards_templates, [:company_id, :name],
              unique: true,
              name: "index_scorecards_templates_on_company_and_name"

    # Allow interview phases to reference a scorecard template
    add_reference :interview_phases, :scorecard_template,
                  type: :uuid,
                  null: true,
                  foreign_key: { to_table: :scorecards_templates, on_delete: :nullify }

    # Remove rating_scale from categories — platform uses fixed 1-5 scale
    remove_column :scorecard_template_categories, :rating_scale, :integer, default: 5, null: false
  end
end
