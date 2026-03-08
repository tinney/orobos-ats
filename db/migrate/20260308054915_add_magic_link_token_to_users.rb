class AddMagicLinkTokenToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :magic_link_token_digest, :string
    add_column :users, :magic_link_token_sent_at, :datetime

    add_index :users, :magic_link_token_digest, unique: true
  end
end
