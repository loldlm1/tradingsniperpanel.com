class AddUsersEmailPrefixIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  INDEX_NAME = "index_users_on_lower_email_pattern".freeze

  def up
    execute <<~SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS #{INDEX_NAME}
      ON users (LOWER(email) text_pattern_ops)
    SQL
  end

  def down
    execute "DROP INDEX CONCURRENTLY IF EXISTS #{INDEX_NAME}"
  end
end
