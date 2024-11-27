# frozen_string_literal: true

class AppendSiteIdToTransactionalTables < ActiveRecord::Migration[7.0]

  def up
    conf = Rails.configuration.database_configuration[Rails.env]
    conf = conf['primary'] if conf.key?('primary')

    user = conf['username'] 
    password = conf['password']
    db = conf['database']
    host = conf['host']

    file = Rails.root.join('db', 'migrate', 'composite_keys.sql')

    command = "mysql -h#{host} -u#{user} -p#{password} #{db} < #{file} -f -v"
    if system(command)
      puts 'Done'
    else
      raise 'Failed'
    end
  end
end
