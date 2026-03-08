class AddCoverLetterToApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :applications, :cover_letter, :text
  end
end
