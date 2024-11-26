# frozen_string_literal: true

# Centralized EMR Migration
class CentralizedEmrMigration < ActiveRecord::Migration[7.0]
  TABLES = %w[drug_order encounter obs orders patient_program patient_state person_address
              pharmacy_batch_item pharmacy_batch pharmacy_stock_balance pharmacy_stock_verification
              pharmacy role_privilege role_role users].freeze
  def change
    foreign_keys = []
    primary_keys = []
    tables = ActiveRecord::Base.connection.tables
    puts "These are the #{TABLES}"
    populate_variables(tables:, foreign_keys:, primary_keys:)
    remove_foreign_keys(foreign_keys:)
    remove_primary_keys(primary_keys:)
    change_column_type(primary_keys:)
    add_site_id(primary_keys:)
    add_composite_primary_key(primary_keys:)
    add_foreign_keys(foreign_keys:)
  end

  # rubocop:disable Metrics/MethodLength
  def populate_variables(tables:, foreign_keys:, primary_keys:)
    tables.each do |table|
      next unless TABLES.include?(table)

      ActiveRecord::Base.connection.foreign_keys(table).each do |fk|
        foreign_keys << {
          primary_table_name: fk.to_table,
          foreign_table_name: table,
          primary_column_name: fk.primary_key,
          foreign_column_name: fk.column,
          key_name: fk.name
        }
      end

      ActiveRecord::Base.connection.primary_keys(table).map do |pk|
        primary_keys << {
          table_name: table,
          column_name: pk
        }
      end
    end
  end
  # rubocop:enable Metrics/MethodLength

  def remove_foreign_keys(foreign_keys:)
    foreign_keys.each do |fk|
      puts "Removing foreign key #{fk[:key_name]} from #{fk[:foreign_table_name]} and #{fk[:primary_table_name]}"
      next unless TABLES.include?(fk[:primary_table_name])

      remove_foreign_key fk[:foreign_table_name], name: fk[:key_name]
    end
  end

  def remove_primary_keys(primary_keys:)
    primary_keys.each do |pk|
      ActiveRecord::Base.connection.execute <<~SQL
        ALTER TABLE #{pk[:table_name]} DROP PRIMARY KEY
      SQL
    end
  end

  def change_column_type(primary_keys:)
    # we need to change them to bigint from integer
    primary_keys.each do |pk|
      change_column pk[:table_name], pk[:column_name], :bigint
    end
  end

  def add_site_id(primary_keys:)
    site_id = GlobalProperty.find_by_property('current_health_center_id').property_value
    primary_keys.each do |pk|
      add_column pk[:table_name], :site_id, :bigint, default: site_id

      add_foreign_key pk[:table_name], :location, column: :site_id, primary_key: :location_id,
                                                  name: "fk_#{pk[:table_name]}_location_id"
    end
  end

  def add_composite_primary_key(primary_keys:)
    primary_keys.each do |pk|
      ActiveRecord::Base.connection.execute <<~SQL
        ALTER TABLE #{pk[:table_name]} ADD PRIMARY KEY (#{pk[:column_name]}, site_id)
      SQL
    end
  end

  def add_foreign_keys(foreign_keys:)
    # the new foreign key will contain the composite primary key and the site_id
    foreign_keys.each do |fk|
      next unless TABLES.include?(fk[:primary_table_name])

      ActiveRecord::Base.connection.execute <<~SQL
        ALTER TABLE #{fk[:foreign_table_name]} ADD FOREIGN KEY (#{fk[:foreign_column_name]}, site_id) REFERENCES #{fk[:primary_table_name]}(#{fk[:primary_column_name]}, site_id)
      SQL
    end
  end
end
