# Create missing tables

# Add Missing columns to concept_name
connection = ActiveRecord::Base.connection

unless connection.column_exists?(:concept_name, :concept_name_type)
  connection.add_column :concept_name, :concept_name_type, :string, limit: 50
end

unless connection.column_exists?(:concept_name, :locale_preferred)
  connection.add_column :concept_name, :locale_preferred, :string, limit: 4
end

unless connection.column_exists?(:patient_program, :location_id)
  connection.add_column :patient_program, :location_id, :integer
end

unless connection.column_exists?(:obs, :location_id)
  connection.add_column :obs, :location_id, :integer
end

connection.change_column :obs, :location_id, :integer, default: nil, null: true

ActiveRecord::Base.connection.execute(<<~SQL)
  CREATE TABLE IF NOT EXISTS `order_extension` (
    `order_extension_id` int(11) NOT NULL AUTO_INCREMENT,
    `order_id` int(11) NOT NULL,
    `value` varchar(50) NOT NULL DEFAULT '',
    `creator` int(11) NOT NULL DEFAULT '0',
    `date_created` datetime NOT NULL DEFAULT '1900-01-01 00:00:00',
    `voided` tinyint(1) NOT NULL DEFAULT '0',
    `voided_by` int(11) DEFAULT NULL,
    `date_voided` datetime DEFAULT NULL,
    `void_reason` varchar(255) DEFAULT NULL,
    PRIMARY KEY (`order_extension_id`),
    KEY `user_who_created_ext` (`creator`),
    KEY `user_who_retired_ext` (`voided_by`),
    KEY `retired_status` (`voided`),
    CONSTRAINT `user_who_created_extension` FOREIGN KEY (`creator`) REFERENCES `users` (`user_id`),
    CONSTRAINT `user_who_voided_extension` FOREIGN KEY (`voided_by`) REFERENCES `users` (`user_id`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
SQL

# Recreate Patient Identifier table
ActiveRecord::Base.connection.execute(<<~SQL)
  CREATE TABLE IF NOT EXISTS `patient_identifier_main` (
    `patient_identifier_id` int NOT NULL AUTO_INCREMENT,
    `patient_id` int NOT NULL DEFAULT '0',
    `identifier` varchar(50) NOT NULL DEFAULT '',
    `identifier_type` int NOT NULL DEFAULT '0',
    `preferred` smallint NOT NULL DEFAULT '0',
    `location_id` int NOT NULL DEFAULT '0',
    `creator` int NOT NULL DEFAULT '0',
    `date_created` datetime NOT NULL DEFAULT '1900-01-01 00:00:00',
    `voided` smallint NOT NULL DEFAULT '0',
    `voided_by` int DEFAULT NULL,
    `date_voided` datetime DEFAULT NULL,
    `void_reason` varchar(255) DEFAULT NULL,
    `uuid` char(38) NOT NULL,
    PRIMARY KEY (`patient_identifier_id`),
    UNIQUE KEY `patient_identifier_uuid_index` (`uuid`),
    KEY `identifier_creator` (`creator`),
    KEY `identifier_voider` (`voided_by`),
    KEY `identifier_location` (`location_id`),
    KEY `identifier_name` (`identifier`),
    KEY `idx_patient_identifier_patient` (`patient_id`)
  ) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb3;
SQL

puts 'Starting data migration from OldPatient to the new table...'

new_table_name = 'patient_identifier_main' # Replace with the actual name of your new table

new_rows = []
existing_rows = ActiveRecord::Base.connection.exec_query('SELECT patient_id, identifier, identifier_type FROM patient_identifier_main').to_a
existing_set = existing_rows.map { |r| [r['patient_id'], r['identifier'], r['identifier_type']] }.to_set

old_patients = ActiveRecord::Base.connection.exec_query('SELECT * FROM patient_identifier')

old_patients.each do |old_patient|
  key = [old_patient['patient_id'], old_patient['identifier'], old_patient['identifier_type']]
  next if existing_set.include?(key)

  new_rows << [
    old_patient['voided_by'],
    old_patient['voided'],
    old_patient['void_reason'],
    SecureRandom.uuid,
    old_patient['preferred'],
    old_patient['patient_id'],
    old_patient['location_id'],
    old_patient['identifier_type'],
    old_patient['identifier'],
    old_patient['date_voided'],
    old_patient['date_created'],
    old_patient['creator']
  ]
end

unless new_rows.empty?
  values_sql = new_rows.map do
    "(#{(['?'] * 12).join(', ')})"
  end.join(', ')

  sql = <<~SQL
    INSERT INTO #{new_table_name} (
      voided_by, voided, void_reason, uuid, preferred,
      patient_id, location_id, identifier_type, identifier,
      date_voided, date_created, creator
    ) VALUES #{values_sql}
  SQL

  ActiveRecord::Base.connection.exec_insert(
    ActiveRecord::Base.send(:sanitize_sql_array, [sql, *new_rows.flatten])
  )
end
puts "Data migration to #{new_table_name} complete."

ActiveRecord::Base.connection.drop_table('patient_identifier')
puts "Old table 'patient_identifier' has been dropped."

ActiveRecord::Base.connection.rename_table('patient_identifier_main', 'patient_identifier')
puts "Renamed table 'patient_identifier_main' to 'patient_identifier'."

ActiveRecord::Base.connection.execute(<<-SQL)
  ALTER TABLE patient_identifier
  ADD CONSTRAINT `defines_identifier_type`
    FOREIGN KEY (`identifier_type`)
    REFERENCES `patient_identifier_type` (`patient_identifier_type_id`),
  ADD CONSTRAINT `identifier_creator`
    FOREIGN KEY (`creator`)
    REFERENCES `users` (`user_id`),
  ADD CONSTRAINT `identifier_voider`
    FOREIGN KEY (`voided_by`)
    REFERENCES `users` (`user_id`),
  ADD CONSTRAINT `identifies_patient`
    FOREIGN KEY (`patient_id`)
    REFERENCES `patient` (`patient_id`),
  ADD CONSTRAINT `patient_identifier_ibfk_2`
    FOREIGN KEY (`location_id`)
    REFERENCES `location` (`location_id`);
SQL

migrations_to_skip = %w[
  20091009094538
  20091009125056
  20091009125602
  20091211111847
  20091211111940
  20100510073658
  20101129190928
  20101129190928
  20110214131134
  20110602192435
  20110604142932
  20110609132925
  20110614184541
  20110726131026
  20110727100353
  20110727100435
  20110727100509
  20140221071909
  20140221071959
  20140728112036
  20160914173912
  20170309093939
  20171103064127
  20171114083901
  20190515130847
  20190516134103
  20190523131939
  20190527130805
  20200624084028
  20200624084345
  20200624084431
  20210415173348
  20220403182327
  20220725075253
  20230309133251
  20230823071343
  20190604100015
  20190604113533
  20190612113802
  20200928133511
  20220105061145
  20220105140130
  20220524083521
  20220913143642
  20240625064618
  20181210122430 
]

migrations_to_skip.each { |migration| ActiveRecord::SchemaMigration.find_or_create_by!(version: migration) }

migration = ActiveRecord::MigrationContext.new(
  ActiveRecord::Migrator.migrations_paths,
  ActiveRecord::SchemaMigration
)

migration.run(:up, 20250325071602)

sql_files = %i[spine_adaptaion bypass_migrations]

sql_files.each do |file|
  sql = File.read("db/sql/#{file}.sql")
  statements = sql.split(/;[\r\n]+/)
  statements.each do |statement|
    next if statement.strip.empty?

    ActiveRecord::Base.connection.execute(statement)
  end
end

puts 'Importing art updated meta-data'
`./bin/update_art_metadata.sh #{Rails.env}`

# Set site to queens
ActiveRecord::Base.connection.execute("UPDATE `global_property` SET `property_value` = '614' WHERE `property` = 'current_health_center_id';")
ActiveRecord::Base.connection.execute("UPDATE `global_property` SET `property_value` = 'Queen Elizabeth Central Hospital' WHERE `property` = 'current_health_center_name';")
ActiveRecord::Base.connection.execute("UPDATE `global_property` SET `property_value` = 'QECH' WHERE `property` = 'site_prefix';")
# Update program ID
ActiveRecord::Base.connection.execute('UPDATE encounter SET program_id = 31;')
User.where(user_id: 1).update_all(person_id: 1)

