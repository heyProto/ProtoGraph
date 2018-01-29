class AlterUtf8Database < ActiveRecord::Migration[5.1]
  def db
    ActiveRecord::Base.connection
  end

  def up
    execute "ALTER DATABASE `#{db.current_database}` CHARACTER SET utf8;"
    db.tables.each do |table|
      execute "ALTER TABLE `#{table}` CHARACTER SET = utf8;"
    end
  end
end
