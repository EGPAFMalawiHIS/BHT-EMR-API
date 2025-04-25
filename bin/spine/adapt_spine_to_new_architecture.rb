# Create missing tables

# Add Missing columns to concept_name
connection = ActiveRecord::Base.connection

unless connection.column_exists?(:concept_name, :concept_name_type)
  connection.add_column :concept_name, :concept_name_type, :string, limit: 50
end

unless connection.column_exists?(:concept_name, :locale_preferred)
  connection.add_column :concept_name, :locale_preferred, :string, limit: 4
end


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
  20140723080240
  20140728112036
  20160112152154
  20160914173912
  20170309093939
  20171103064127
  20171114083901
  20190219134117
  20190410120250
  20190410120646
  20190503064300
  20190508125042
  20190510124325
  20190515130847
  20190516091445
  20190516134103
  20190523131939
  20190527122235
  20190527130805
  20200624084028
  20200624084345
  20200624084431
  20210210114015
  20210318125442
  20210415173348
  20220403182327
  20220420085001
  20220725075253
  20220725095428
  20221112075527
  20230309133251
  20230823071343
  20190604094625
  20190604100015
  20190604113533
  20190612113802
  20200928133511
  20220105061145
  20220105140130
  20220524083521
  20220913143642
  20230404133238
  20240625064618
]

migrations_to_skip.each { |migration| ActiveRecord::SchemaMigration.find_or_create_by!(version: migration) }

sql_files = %i[spine_adaptaion]

sql_files.each do |file|
  sql = File.read("db/sql/#{file}.sql")
  statements = sql.split(/;[\r\n]+/)
  statements.each do |statement|
    next if statement.strip.empty?

    ActiveRecord::Base.connection.execute(statement)
  end
end

`./bin/update_art_metadata.sh #{Rails.env}`

# Set site to queens
ActiveRecord::Base.connection.execute("UPDATE `global_property` SET `property_value` = '614' WHERE `property` = 'current_health_center_id';")
ActiveRecord::Base.connection.execute("UPDATE `global_property` SET `property_value` = 'Queen Elizabeth Central Hospital' WHERE `property` = 'current_health_center_name';")
ActiveRecord::Base.connection.execute("UPDATE `global_property` SET `property_value` = 'QECH' WHERE `property` = 'site_prefix';")
# Update program ID
ActiveRecord::Base.connection.execute('UPDATE encounter SET program_id = 31;')
User.where(user_id: 1).update_all(person_id: 1)

