class AddPhoneToCandidates < ActiveRecord::Migration[8.1]
  def change
    add_column :candidates, :phone, :string
  end
end
