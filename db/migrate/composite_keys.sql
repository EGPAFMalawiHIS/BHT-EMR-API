SET sql_mode = 'ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION';
ALTER TABLE users ADD COLUMN site_id INTEGER DEFAULT 0;
ALTER TABLE person_name ADD COLUMN site_id INTEGER DEFAULT 0;
ALTER TABLE drug_ingredients ADD COLUMN site_id INTEGER DEFAULT 0;
ALTER TABLE drug_order ADD COLUMN site_id INTEGER DEFAULT 0;
ALTER TABLE encounter ADD COLUMN site_id INTEGER DEFAULT 0;
ALTER TABLE orders ADD COLUMN site_id INTEGER DEFAULT 0;
ALTER TABLE obs ADD COLUMN site_id INTEGER DEFAULT 0;
ALTER TABLE patient_program ADD COLUMN site_id INTEGER DEFAULT 0;
ALTER TABLE patient_state ADD COLUMN site_id INTEGER DEFAULT 0;
ALTER TABLE person_address ADD COLUMN site_id INTEGER DEFAULT 0;
ALTER TABLE pharmacies ADD COLUMN site_id INTEGER DEFAULT 0;
ALTER TABLE pharmacy_batch_items ADD COLUMN site_id INTEGER DEFAULT 0;
ALTER TABLE pharmacy_batches ADD COLUMN site_id INTEGER DEFAULT 0;
ALTER TABLE pharmacy_stock_balances ADD COLUMN site_id INTEGER DEFAULT 0;
ALTER TABLE pharmacy_stock_verifications ADD COLUMN site_id INTEGER DEFAULT 0;
ALTER TABLE relationship ADD COLUMN site_id INTEGER DEFAULT 0;
ALTER TABLE users DROP FOREIGN KEY `fk_rails_fa67535741`;
ALTER TABLE users
DROP PRIMARY KEY,
ADD PRIMARY KEY (user_id, site_id);
ALTER TABLE users DROP FOREIGN KEY `person_id_for_user`;
DROP INDEX person_id_for_user ON users;
ALTER TABLE users DROP FOREIGN KEY `user_creator`;
DROP INDEX user_creator ON users;
ALTER TABLE users DROP FOREIGN KEY `user_who_changed_user`;
DROP INDEX user_who_changed_user ON users;
ALTER TABLE users DROP FOREIGN KEY `user_who_retired_this_user`;
DROP INDEX user_who_retired_this_user ON users;
ALTER TABLE person_name DROP FOREIGN KEY `fk_rails_fa67535741`;
ALTER TABLE person_name
DROP PRIMARY KEY,
ADD PRIMARY KEY (person_name_id, site_id);
ALTER TABLE person_name DROP FOREIGN KEY `person_id_for_user`;
ALTER TABLE person_name DROP FOREIGN KEY `user_creator`;
ALTER TABLE person_name DROP FOREIGN KEY `user_who_changed_user`;
ALTER TABLE person_name DROP FOREIGN KEY `user_who_retired_this_user`;
ALTER TABLE person_name DROP FOREIGN KEY `name for person`;
ALTER TABLE person_name DROP FOREIGN KEY `user_who_made_name`;
DROP INDEX user_who_made_name ON person_name;
ALTER TABLE person_name DROP FOREIGN KEY `user_who_voided_name`;
DROP INDEX user_who_voided_name ON person_name;
ALTER TABLE drug_ingredients DROP FOREIGN KEY `fk_rails_fa67535741`;
ALTER TABLE drug_ingredients
DROP PRIMARY KEY,
ADD PRIMARY KEY (id, site_id);
ALTER TABLE drug_ingredients DROP FOREIGN KEY `person_id_for_user`;
ALTER TABLE drug_ingredients DROP FOREIGN KEY `user_creator`;
ALTER TABLE drug_ingredients DROP FOREIGN KEY `user_who_changed_user`;
ALTER TABLE drug_ingredients DROP FOREIGN KEY `user_who_retired_this_user`;
ALTER TABLE drug_ingredients DROP FOREIGN KEY `name for person`;
ALTER TABLE drug_ingredients DROP FOREIGN KEY `user_who_made_name`;
ALTER TABLE drug_ingredients DROP FOREIGN KEY `user_who_voided_name`;
ALTER TABLE drug_order DROP FOREIGN KEY `fk_rails_fa67535741`;
ALTER TABLE drug_order DROP FOREIGN KEY `person_id_for_user`;
ALTER TABLE drug_order DROP FOREIGN KEY `user_creator`;
ALTER TABLE drug_order DROP FOREIGN KEY `user_who_changed_user`;
ALTER TABLE drug_order DROP FOREIGN KEY `user_who_retired_this_user`;
ALTER TABLE drug_order DROP FOREIGN KEY `name for person`;
ALTER TABLE drug_order DROP FOREIGN KEY `user_who_made_name`;
ALTER TABLE drug_order DROP FOREIGN KEY `user_who_voided_name`;
ALTER TABLE encounter DROP FOREIGN KEY `fk_rails_fa67535741`;
ALTER TABLE encounter
DROP PRIMARY KEY,
ADD PRIMARY KEY (encounter_id, site_id);
ALTER TABLE encounter DROP FOREIGN KEY `person_id_for_user`;
ALTER TABLE encounter DROP FOREIGN KEY `user_creator`;
ALTER TABLE encounter DROP FOREIGN KEY `user_who_changed_user`;
ALTER TABLE encounter DROP FOREIGN KEY `user_who_retired_this_user`;
ALTER TABLE encounter DROP FOREIGN KEY `name for person`;
ALTER TABLE encounter DROP FOREIGN KEY `user_who_made_name`;
ALTER TABLE encounter DROP FOREIGN KEY `user_who_voided_name`;
ALTER TABLE encounter DROP FOREIGN KEY `encounter_changed_by`;
DROP INDEX encounter_changed_by ON encounter;
ALTER TABLE encounter DROP FOREIGN KEY `encounter_form`;
DROP INDEX encounter_form ON encounter;
ALTER TABLE encounter DROP FOREIGN KEY `encounter_ibfk_1`;
ALTER TABLE encounter DROP FOREIGN KEY `encounter_location`;
DROP INDEX encounter_location ON encounter;
ALTER TABLE encounter DROP FOREIGN KEY `encounter_patient`;
DROP INDEX encounter_patient ON encounter;
ALTER TABLE encounter DROP FOREIGN KEY `encounter_provider`;
DROP INDEX encounter_provider ON encounter;
ALTER TABLE encounter DROP FOREIGN KEY `encounter_type_id`;
DROP INDEX encounter_type_id ON encounter;
ALTER TABLE encounter DROP FOREIGN KEY `user_who_voided_encounter`;
DROP INDEX user_who_voided_encounter ON encounter;
ALTER TABLE orders DROP FOREIGN KEY `fk_rails_fa67535741`;
ALTER TABLE orders
DROP PRIMARY KEY,
ADD PRIMARY KEY (order_id, site_id);
ALTER TABLE orders DROP FOREIGN KEY `person_id_for_user`;
ALTER TABLE orders DROP FOREIGN KEY `user_creator`;
ALTER TABLE orders DROP FOREIGN KEY `user_who_changed_user`;
ALTER TABLE orders DROP FOREIGN KEY `user_who_retired_this_user`;
ALTER TABLE orders DROP FOREIGN KEY `name for person`;
ALTER TABLE orders DROP FOREIGN KEY `user_who_made_name`;
ALTER TABLE orders DROP FOREIGN KEY `user_who_voided_name`;
ALTER TABLE orders DROP FOREIGN KEY `encounter_changed_by`;
ALTER TABLE orders DROP FOREIGN KEY `encounter_form`;
ALTER TABLE orders DROP FOREIGN KEY `encounter_ibfk_1`;
ALTER TABLE orders DROP FOREIGN KEY `encounter_location`;
ALTER TABLE orders DROP FOREIGN KEY `encounter_patient`;
ALTER TABLE orders DROP FOREIGN KEY `encounter_provider`;
ALTER TABLE orders DROP FOREIGN KEY `encounter_type_id`;
ALTER TABLE orders DROP FOREIGN KEY `user_who_voided_encounter`;
ALTER TABLE orders DROP FOREIGN KEY `discontinued_because`;
DROP INDEX discontinued_because ON orders;
ALTER TABLE orders DROP FOREIGN KEY `obs_for_order`;
DROP INDEX obs_for_order ON orders;
ALTER TABLE orders DROP FOREIGN KEY `order_creator`;
DROP INDEX order_creator ON orders;
ALTER TABLE orders DROP FOREIGN KEY `order_for_patient`;
DROP INDEX order_for_patient ON orders;
ALTER TABLE orders DROP FOREIGN KEY `orderer_not_drug`;
DROP INDEX orderer_not_drug ON orders;
ALTER TABLE orders DROP FOREIGN KEY `orders_in_encounter`;
DROP INDEX orders_in_encounter ON orders;
ALTER TABLE orders DROP FOREIGN KEY `type_of_order`;
DROP INDEX type_of_order ON orders;
ALTER TABLE orders DROP FOREIGN KEY `user_who_discontinued_order`;
DROP INDEX user_who_discontinued_order ON orders;
ALTER TABLE orders DROP FOREIGN KEY `user_who_voided_order`;
DROP INDEX user_who_voided_order ON orders;
ALTER TABLE obs DROP FOREIGN KEY `fk_rails_fa67535741`;
ALTER TABLE obs
DROP PRIMARY KEY,
ADD PRIMARY KEY (obs_id, site_id);
ALTER TABLE obs DROP FOREIGN KEY `person_id_for_user`;
ALTER TABLE obs DROP FOREIGN KEY `user_creator`;
ALTER TABLE obs DROP FOREIGN KEY `user_who_changed_user`;
ALTER TABLE obs DROP FOREIGN KEY `user_who_retired_this_user`;
ALTER TABLE obs DROP FOREIGN KEY `name for person`;
ALTER TABLE obs DROP FOREIGN KEY `user_who_made_name`;
ALTER TABLE obs DROP FOREIGN KEY `user_who_voided_name`;
ALTER TABLE obs DROP FOREIGN KEY `encounter_changed_by`;
ALTER TABLE obs DROP FOREIGN KEY `encounter_form`;
ALTER TABLE obs DROP FOREIGN KEY `encounter_ibfk_1`;
ALTER TABLE obs DROP FOREIGN KEY `encounter_location`;
ALTER TABLE obs DROP FOREIGN KEY `encounter_patient`;
ALTER TABLE obs DROP FOREIGN KEY `encounter_provider`;
ALTER TABLE obs DROP FOREIGN KEY `encounter_type_id`;
ALTER TABLE obs DROP FOREIGN KEY `user_who_voided_encounter`;
ALTER TABLE obs DROP FOREIGN KEY `discontinued_because`;
ALTER TABLE obs DROP FOREIGN KEY `obs_for_order`;
ALTER TABLE obs DROP FOREIGN KEY `order_creator`;
ALTER TABLE obs DROP FOREIGN KEY `order_for_patient`;
ALTER TABLE obs DROP FOREIGN KEY `orderer_not_drug`;
ALTER TABLE obs DROP FOREIGN KEY `orders_in_encounter`;
ALTER TABLE obs DROP FOREIGN KEY `type_of_order`;
ALTER TABLE obs DROP FOREIGN KEY `user_who_discontinued_order`;
ALTER TABLE obs DROP FOREIGN KEY `user_who_voided_order`;
ALTER TABLE obs DROP FOREIGN KEY `answer_concept`;
DROP INDEX answer_concept ON obs;
ALTER TABLE obs DROP FOREIGN KEY `answer_concept_drug`;
DROP INDEX answer_concept_drug ON obs;
ALTER TABLE obs DROP FOREIGN KEY `encounter_observations`;
DROP INDEX encounter_observations ON obs;
ALTER TABLE obs DROP FOREIGN KEY `obs_concept`;
DROP INDEX obs_concept ON obs;
ALTER TABLE obs DROP FOREIGN KEY `obs_enterer`;
DROP INDEX obs_enterer ON obs;
ALTER TABLE obs DROP FOREIGN KEY `obs_grouping_id`;
DROP INDEX obs_grouping_id ON obs;
ALTER TABLE obs DROP FOREIGN KEY `obs_location`;
DROP INDEX obs_location ON obs;
ALTER TABLE obs DROP FOREIGN KEY `obs_name_of_coded_value`;
DROP INDEX obs_name_of_coded_value ON obs;
ALTER TABLE obs DROP FOREIGN KEY `obs_order`;
DROP INDEX obs_order ON obs;
ALTER TABLE obs DROP FOREIGN KEY `person_obs`;
ALTER TABLE obs DROP FOREIGN KEY `user_who_voided_obs`;
DROP INDEX user_who_voided_obs ON obs;
ALTER TABLE patient_program DROP FOREIGN KEY `fk_rails_fa67535741`;
ALTER TABLE patient_program
DROP PRIMARY KEY,
ADD PRIMARY KEY (patient_program_id, site_id);
ALTER TABLE patient_program DROP FOREIGN KEY `person_id_for_user`;
ALTER TABLE patient_program DROP FOREIGN KEY `user_creator`;
ALTER TABLE patient_program DROP FOREIGN KEY `user_who_changed_user`;
ALTER TABLE patient_program DROP FOREIGN KEY `user_who_retired_this_user`;
ALTER TABLE patient_program DROP FOREIGN KEY `name for person`;
ALTER TABLE patient_program DROP FOREIGN KEY `user_who_made_name`;
ALTER TABLE patient_program DROP FOREIGN KEY `user_who_voided_name`;
ALTER TABLE patient_program DROP FOREIGN KEY `encounter_changed_by`;
ALTER TABLE patient_program DROP FOREIGN KEY `encounter_form`;
ALTER TABLE patient_program DROP FOREIGN KEY `encounter_ibfk_1`;
ALTER TABLE patient_program DROP FOREIGN KEY `encounter_location`;
ALTER TABLE patient_program DROP FOREIGN KEY `encounter_patient`;
ALTER TABLE patient_program DROP FOREIGN KEY `encounter_provider`;
ALTER TABLE patient_program DROP FOREIGN KEY `encounter_type_id`;
ALTER TABLE patient_program DROP FOREIGN KEY `user_who_voided_encounter`;
ALTER TABLE patient_program DROP FOREIGN KEY `discontinued_because`;
ALTER TABLE patient_program DROP FOREIGN KEY `obs_for_order`;
ALTER TABLE patient_program DROP FOREIGN KEY `order_creator`;
ALTER TABLE patient_program DROP FOREIGN KEY `order_for_patient`;
ALTER TABLE patient_program DROP FOREIGN KEY `orderer_not_drug`;
ALTER TABLE patient_program DROP FOREIGN KEY `orders_in_encounter`;
ALTER TABLE patient_program DROP FOREIGN KEY `type_of_order`;
ALTER TABLE patient_program DROP FOREIGN KEY `user_who_discontinued_order`;
ALTER TABLE patient_program DROP FOREIGN KEY `user_who_voided_order`;
ALTER TABLE patient_program DROP FOREIGN KEY `answer_concept`;
ALTER TABLE patient_program DROP FOREIGN KEY `answer_concept_drug`;
ALTER TABLE patient_program DROP FOREIGN KEY `encounter_observations`;
ALTER TABLE patient_program DROP FOREIGN KEY `obs_concept`;
ALTER TABLE patient_program DROP FOREIGN KEY `obs_enterer`;
ALTER TABLE patient_program DROP FOREIGN KEY `obs_grouping_id`;
ALTER TABLE patient_program DROP FOREIGN KEY `obs_location`;
ALTER TABLE patient_program DROP FOREIGN KEY `obs_name_of_coded_value`;
ALTER TABLE patient_program DROP FOREIGN KEY `obs_order`;
ALTER TABLE patient_program DROP FOREIGN KEY `person_obs`;
ALTER TABLE patient_program DROP FOREIGN KEY `user_who_voided_obs`;
ALTER TABLE patient_program DROP FOREIGN KEY `patient_in_program`;
DROP INDEX patient_in_program ON patient_program;
ALTER TABLE patient_program DROP FOREIGN KEY `patient_program_creator`;
DROP INDEX patient_program_creator ON patient_program;
ALTER TABLE patient_program DROP FOREIGN KEY `program_for_patient`;
DROP INDEX program_for_patient ON patient_program;
ALTER TABLE patient_program DROP FOREIGN KEY `user_who_changed`;
DROP INDEX user_who_changed ON patient_program;
ALTER TABLE patient_program DROP FOREIGN KEY `user_who_voided_patient_program`;
DROP INDEX user_who_voided_patient_program ON patient_program;
ALTER TABLE patient_state DROP FOREIGN KEY `fk_rails_fa67535741`;
ALTER TABLE patient_state
DROP PRIMARY KEY,
ADD PRIMARY KEY (patient_state_id, site_id);
ALTER TABLE patient_state DROP FOREIGN KEY `person_id_for_user`;
ALTER TABLE patient_state DROP FOREIGN KEY `user_creator`;
ALTER TABLE patient_state DROP FOREIGN KEY `user_who_changed_user`;
ALTER TABLE patient_state DROP FOREIGN KEY `user_who_retired_this_user`;
ALTER TABLE patient_state DROP FOREIGN KEY `name for person`;
ALTER TABLE patient_state DROP FOREIGN KEY `user_who_made_name`;
ALTER TABLE patient_state DROP FOREIGN KEY `user_who_voided_name`;
ALTER TABLE patient_state DROP FOREIGN KEY `encounter_changed_by`;
ALTER TABLE patient_state DROP FOREIGN KEY `encounter_form`;
ALTER TABLE patient_state DROP FOREIGN KEY `encounter_ibfk_1`;
ALTER TABLE patient_state DROP FOREIGN KEY `encounter_location`;
ALTER TABLE patient_state DROP FOREIGN KEY `encounter_patient`;
ALTER TABLE patient_state DROP FOREIGN KEY `encounter_provider`;
ALTER TABLE patient_state DROP FOREIGN KEY `encounter_type_id`;
ALTER TABLE patient_state DROP FOREIGN KEY `user_who_voided_encounter`;
ALTER TABLE patient_state DROP FOREIGN KEY `discontinued_because`;
ALTER TABLE patient_state DROP FOREIGN KEY `obs_for_order`;
ALTER TABLE patient_state DROP FOREIGN KEY `order_creator`;
ALTER TABLE patient_state DROP FOREIGN KEY `order_for_patient`;
ALTER TABLE patient_state DROP FOREIGN KEY `orderer_not_drug`;
ALTER TABLE patient_state DROP FOREIGN KEY `orders_in_encounter`;
ALTER TABLE patient_state DROP FOREIGN KEY `type_of_order`;
ALTER TABLE patient_state DROP FOREIGN KEY `user_who_discontinued_order`;
ALTER TABLE patient_state DROP FOREIGN KEY `user_who_voided_order`;
ALTER TABLE patient_state DROP FOREIGN KEY `answer_concept`;
ALTER TABLE patient_state DROP FOREIGN KEY `answer_concept_drug`;
ALTER TABLE patient_state DROP FOREIGN KEY `encounter_observations`;
ALTER TABLE patient_state DROP FOREIGN KEY `obs_concept`;
ALTER TABLE patient_state DROP FOREIGN KEY `obs_enterer`;
ALTER TABLE patient_state DROP FOREIGN KEY `obs_grouping_id`;
ALTER TABLE patient_state DROP FOREIGN KEY `obs_location`;
ALTER TABLE patient_state DROP FOREIGN KEY `obs_name_of_coded_value`;
ALTER TABLE patient_state DROP FOREIGN KEY `obs_order`;
ALTER TABLE patient_state DROP FOREIGN KEY `person_obs`;
ALTER TABLE patient_state DROP FOREIGN KEY `user_who_voided_obs`;
ALTER TABLE patient_state DROP FOREIGN KEY `patient_in_program`;
ALTER TABLE patient_state DROP FOREIGN KEY `patient_program_creator`;
ALTER TABLE patient_state DROP FOREIGN KEY `program_for_patient`;
ALTER TABLE patient_state DROP FOREIGN KEY `user_who_changed`;
ALTER TABLE patient_state DROP FOREIGN KEY `user_who_voided_patient_program`;
ALTER TABLE patient_state DROP FOREIGN KEY `patient_program_for_state`;
DROP INDEX patient_program_for_state ON patient_state;
ALTER TABLE patient_state DROP FOREIGN KEY `patient_state_changer`;
DROP INDEX patient_state_changer ON patient_state;
ALTER TABLE patient_state DROP FOREIGN KEY `patient_state_creator`;
DROP INDEX patient_state_creator ON patient_state;
ALTER TABLE patient_state DROP FOREIGN KEY `patient_state_voider`;
DROP INDEX patient_state_voider ON patient_state;
ALTER TABLE patient_state DROP FOREIGN KEY `state_for_patient`;
DROP INDEX state_for_patient ON patient_state;
ALTER TABLE person_address DROP FOREIGN KEY `fk_rails_fa67535741`;
ALTER TABLE person_address
DROP PRIMARY KEY,
ADD PRIMARY KEY (person_address_id, site_id);
ALTER TABLE person_address DROP FOREIGN KEY `person_id_for_user`;
ALTER TABLE person_address DROP FOREIGN KEY `user_creator`;
ALTER TABLE person_address DROP FOREIGN KEY `user_who_changed_user`;
ALTER TABLE person_address DROP FOREIGN KEY `user_who_retired_this_user`;
ALTER TABLE person_address DROP FOREIGN KEY `name for person`;
ALTER TABLE person_address DROP FOREIGN KEY `user_who_made_name`;
ALTER TABLE person_address DROP FOREIGN KEY `user_who_voided_name`;
ALTER TABLE person_address DROP FOREIGN KEY `encounter_changed_by`;
ALTER TABLE person_address DROP FOREIGN KEY `encounter_form`;
ALTER TABLE person_address DROP FOREIGN KEY `encounter_ibfk_1`;
ALTER TABLE person_address DROP FOREIGN KEY `encounter_location`;
ALTER TABLE person_address DROP FOREIGN KEY `encounter_patient`;
ALTER TABLE person_address DROP FOREIGN KEY `encounter_provider`;
ALTER TABLE person_address DROP FOREIGN KEY `encounter_type_id`;
ALTER TABLE person_address DROP FOREIGN KEY `user_who_voided_encounter`;
ALTER TABLE person_address DROP FOREIGN KEY `discontinued_because`;
ALTER TABLE person_address DROP FOREIGN KEY `obs_for_order`;
ALTER TABLE person_address DROP FOREIGN KEY `order_creator`;
ALTER TABLE person_address DROP FOREIGN KEY `order_for_patient`;
ALTER TABLE person_address DROP FOREIGN KEY `orderer_not_drug`;
ALTER TABLE person_address DROP FOREIGN KEY `orders_in_encounter`;
ALTER TABLE person_address DROP FOREIGN KEY `type_of_order`;
ALTER TABLE person_address DROP FOREIGN KEY `user_who_discontinued_order`;
ALTER TABLE person_address DROP FOREIGN KEY `user_who_voided_order`;
ALTER TABLE person_address DROP FOREIGN KEY `answer_concept`;
ALTER TABLE person_address DROP FOREIGN KEY `answer_concept_drug`;
ALTER TABLE person_address DROP FOREIGN KEY `encounter_observations`;
ALTER TABLE person_address DROP FOREIGN KEY `obs_concept`;
ALTER TABLE person_address DROP FOREIGN KEY `obs_enterer`;
ALTER TABLE person_address DROP FOREIGN KEY `obs_grouping_id`;
ALTER TABLE person_address DROP FOREIGN KEY `obs_location`;
ALTER TABLE person_address DROP FOREIGN KEY `obs_name_of_coded_value`;
ALTER TABLE person_address DROP FOREIGN KEY `obs_order`;
ALTER TABLE person_address DROP FOREIGN KEY `person_obs`;
ALTER TABLE person_address DROP FOREIGN KEY `user_who_voided_obs`;
ALTER TABLE person_address DROP FOREIGN KEY `patient_in_program`;
ALTER TABLE person_address DROP FOREIGN KEY `patient_program_creator`;
ALTER TABLE person_address DROP FOREIGN KEY `program_for_patient`;
ALTER TABLE person_address DROP FOREIGN KEY `user_who_changed`;
ALTER TABLE person_address DROP FOREIGN KEY `user_who_voided_patient_program`;
ALTER TABLE person_address DROP FOREIGN KEY `patient_program_for_state`;
ALTER TABLE person_address DROP FOREIGN KEY `patient_state_changer`;
ALTER TABLE person_address DROP FOREIGN KEY `patient_state_creator`;
ALTER TABLE person_address DROP FOREIGN KEY `patient_state_voider`;
ALTER TABLE person_address DROP FOREIGN KEY `state_for_patient`;
ALTER TABLE person_address DROP FOREIGN KEY `address_for_person`;
ALTER TABLE person_address DROP FOREIGN KEY `patient_address_creator`;
DROP INDEX patient_address_creator ON person_address;
ALTER TABLE person_address DROP FOREIGN KEY `patient_address_void`;
DROP INDEX patient_address_void ON person_address;
ALTER TABLE pharmacies DROP FOREIGN KEY `fk_rails_fa67535741`;
ALTER TABLE pharmacies
DROP PRIMARY KEY,
ADD PRIMARY KEY (id, site_id);
ALTER TABLE pharmacies DROP FOREIGN KEY `person_id_for_user`;
ALTER TABLE pharmacies DROP FOREIGN KEY `user_creator`;
ALTER TABLE pharmacies DROP FOREIGN KEY `user_who_changed_user`;
ALTER TABLE pharmacies DROP FOREIGN KEY `user_who_retired_this_user`;
ALTER TABLE pharmacies DROP FOREIGN KEY `name for person`;
ALTER TABLE pharmacies DROP FOREIGN KEY `user_who_made_name`;
ALTER TABLE pharmacies DROP FOREIGN KEY `user_who_voided_name`;
ALTER TABLE pharmacies DROP FOREIGN KEY `encounter_changed_by`;
ALTER TABLE pharmacies DROP FOREIGN KEY `encounter_form`;
ALTER TABLE pharmacies DROP FOREIGN KEY `encounter_ibfk_1`;
ALTER TABLE pharmacies DROP FOREIGN KEY `encounter_location`;
ALTER TABLE pharmacies DROP FOREIGN KEY `encounter_patient`;
ALTER TABLE pharmacies DROP FOREIGN KEY `encounter_provider`;
ALTER TABLE pharmacies DROP FOREIGN KEY `encounter_type_id`;
ALTER TABLE pharmacies DROP FOREIGN KEY `user_who_voided_encounter`;
ALTER TABLE pharmacies DROP FOREIGN KEY `discontinued_because`;
ALTER TABLE pharmacies DROP FOREIGN KEY `obs_for_order`;
ALTER TABLE pharmacies DROP FOREIGN KEY `order_creator`;
ALTER TABLE pharmacies DROP FOREIGN KEY `order_for_patient`;
ALTER TABLE pharmacies DROP FOREIGN KEY `orderer_not_drug`;
ALTER TABLE pharmacies DROP FOREIGN KEY `orders_in_encounter`;
ALTER TABLE pharmacies DROP FOREIGN KEY `type_of_order`;
ALTER TABLE pharmacies DROP FOREIGN KEY `user_who_discontinued_order`;
ALTER TABLE pharmacies DROP FOREIGN KEY `user_who_voided_order`;
ALTER TABLE pharmacies DROP FOREIGN KEY `answer_concept`;
ALTER TABLE pharmacies DROP FOREIGN KEY `answer_concept_drug`;
ALTER TABLE pharmacies DROP FOREIGN KEY `encounter_observations`;
ALTER TABLE pharmacies DROP FOREIGN KEY `obs_concept`;
ALTER TABLE pharmacies DROP FOREIGN KEY `obs_enterer`;
ALTER TABLE pharmacies DROP FOREIGN KEY `obs_grouping_id`;
ALTER TABLE pharmacies DROP FOREIGN KEY `obs_location`;
ALTER TABLE pharmacies DROP FOREIGN KEY `obs_name_of_coded_value`;
ALTER TABLE pharmacies DROP FOREIGN KEY `obs_order`;
ALTER TABLE pharmacies DROP FOREIGN KEY `person_obs`;
ALTER TABLE pharmacies DROP FOREIGN KEY `user_who_voided_obs`;
ALTER TABLE pharmacies DROP FOREIGN KEY `patient_in_program`;
ALTER TABLE pharmacies DROP FOREIGN KEY `patient_program_creator`;
ALTER TABLE pharmacies DROP FOREIGN KEY `program_for_patient`;
ALTER TABLE pharmacies DROP FOREIGN KEY `user_who_changed`;
ALTER TABLE pharmacies DROP FOREIGN KEY `user_who_voided_patient_program`;
ALTER TABLE pharmacies DROP FOREIGN KEY `patient_program_for_state`;
ALTER TABLE pharmacies DROP FOREIGN KEY `patient_state_changer`;
ALTER TABLE pharmacies DROP FOREIGN KEY `patient_state_creator`;
ALTER TABLE pharmacies DROP FOREIGN KEY `patient_state_voider`;
ALTER TABLE pharmacies DROP FOREIGN KEY `state_for_patient`;
ALTER TABLE pharmacies DROP FOREIGN KEY `address_for_person`;
ALTER TABLE pharmacies DROP FOREIGN KEY `patient_address_creator`;
ALTER TABLE pharmacies DROP FOREIGN KEY `patient_address_void`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `fk_rails_fa67535741`;
ALTER TABLE pharmacy_batch_items
DROP PRIMARY KEY,
ADD PRIMARY KEY (id, site_id);
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `person_id_for_user`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `user_creator`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `user_who_changed_user`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `user_who_retired_this_user`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `name for person`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `user_who_made_name`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `user_who_voided_name`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `encounter_changed_by`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `encounter_form`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `encounter_ibfk_1`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `encounter_location`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `encounter_patient`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `encounter_provider`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `encounter_type_id`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `user_who_voided_encounter`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `discontinued_because`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `obs_for_order`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `order_creator`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `order_for_patient`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `orderer_not_drug`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `orders_in_encounter`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `type_of_order`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `user_who_discontinued_order`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `user_who_voided_order`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `answer_concept`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `answer_concept_drug`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `encounter_observations`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `obs_concept`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `obs_enterer`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `obs_grouping_id`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `obs_location`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `obs_name_of_coded_value`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `obs_order`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `person_obs`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `user_who_voided_obs`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `patient_in_program`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `patient_program_creator`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `program_for_patient`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `user_who_changed`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `user_who_voided_patient_program`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `patient_program_for_state`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `patient_state_changer`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `patient_state_creator`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `patient_state_voider`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `state_for_patient`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `address_for_person`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `patient_address_creator`;
ALTER TABLE pharmacy_batch_items DROP FOREIGN KEY `patient_address_void`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `fk_rails_fa67535741`;
ALTER TABLE pharmacy_batches
DROP PRIMARY KEY,
ADD PRIMARY KEY (id, site_id);
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `person_id_for_user`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `user_creator`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `user_who_changed_user`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `user_who_retired_this_user`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `name for person`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `user_who_made_name`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `user_who_voided_name`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `encounter_changed_by`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `encounter_form`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `encounter_ibfk_1`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `encounter_location`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `encounter_patient`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `encounter_provider`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `encounter_type_id`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `user_who_voided_encounter`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `discontinued_because`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `obs_for_order`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `order_creator`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `order_for_patient`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `orderer_not_drug`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `orders_in_encounter`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `type_of_order`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `user_who_discontinued_order`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `user_who_voided_order`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `answer_concept`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `answer_concept_drug`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `encounter_observations`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `obs_concept`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `obs_enterer`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `obs_grouping_id`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `obs_location`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `obs_name_of_coded_value`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `obs_order`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `person_obs`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `user_who_voided_obs`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `patient_in_program`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `patient_program_creator`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `program_for_patient`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `user_who_changed`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `user_who_voided_patient_program`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `patient_program_for_state`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `patient_state_changer`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `patient_state_creator`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `patient_state_voider`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `state_for_patient`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `address_for_person`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `patient_address_creator`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `patient_address_void`;
ALTER TABLE pharmacy_batches DROP FOREIGN KEY `fk_rails_09e680ca40`;
DROP INDEX fk_rails_09e680ca40 ON pharmacy_batches;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `fk_rails_fa67535741`;
ALTER TABLE pharmacy_stock_balances
DROP PRIMARY KEY,
ADD PRIMARY KEY (id, site_id);
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `person_id_for_user`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `user_creator`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `user_who_changed_user`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `user_who_retired_this_user`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `name for person`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `user_who_made_name`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `user_who_voided_name`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `encounter_changed_by`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `encounter_form`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `encounter_ibfk_1`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `encounter_location`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `encounter_patient`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `encounter_provider`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `encounter_type_id`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `user_who_voided_encounter`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `discontinued_because`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `obs_for_order`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `order_creator`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `order_for_patient`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `orderer_not_drug`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `orders_in_encounter`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `type_of_order`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `user_who_discontinued_order`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `user_who_voided_order`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `answer_concept`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `answer_concept_drug`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `encounter_observations`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `obs_concept`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `obs_enterer`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `obs_grouping_id`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `obs_location`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `obs_name_of_coded_value`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `obs_order`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `person_obs`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `user_who_voided_obs`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `patient_in_program`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `patient_program_creator`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `program_for_patient`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `user_who_changed`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `user_who_voided_patient_program`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `patient_program_for_state`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `patient_state_changer`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `patient_state_creator`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `patient_state_voider`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `state_for_patient`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `address_for_person`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `patient_address_creator`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `patient_address_void`;
ALTER TABLE pharmacy_stock_balances DROP FOREIGN KEY `fk_rails_09e680ca40`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `fk_rails_fa67535741`;
ALTER TABLE pharmacy_stock_verifications
DROP PRIMARY KEY,
ADD PRIMARY KEY (id, site_id);
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `person_id_for_user`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `user_creator`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `user_who_changed_user`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `user_who_retired_this_user`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `name for person`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `user_who_made_name`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `user_who_voided_name`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `encounter_changed_by`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `encounter_form`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `encounter_ibfk_1`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `encounter_location`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `encounter_patient`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `encounter_provider`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `encounter_type_id`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `user_who_voided_encounter`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `discontinued_because`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `obs_for_order`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `order_creator`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `order_for_patient`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `orderer_not_drug`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `orders_in_encounter`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `type_of_order`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `user_who_discontinued_order`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `user_who_voided_order`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `answer_concept`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `answer_concept_drug`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `encounter_observations`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `obs_concept`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `obs_enterer`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `obs_grouping_id`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `obs_location`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `obs_name_of_coded_value`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `obs_order`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `person_obs`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `user_who_voided_obs`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `patient_in_program`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `patient_program_creator`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `program_for_patient`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `user_who_changed`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `user_who_voided_patient_program`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `patient_program_for_state`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `patient_state_changer`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `patient_state_creator`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `patient_state_voider`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `state_for_patient`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `address_for_person`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `patient_address_creator`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `patient_address_void`;
ALTER TABLE pharmacy_stock_verifications DROP FOREIGN KEY `fk_rails_09e680ca40`;
ALTER TABLE relationship DROP FOREIGN KEY `fk_rails_fa67535741`;
ALTER TABLE relationship
DROP PRIMARY KEY,
ADD PRIMARY KEY (relationship_id, site_id);
ALTER TABLE relationship DROP FOREIGN KEY `person_id_for_user`;
ALTER TABLE relationship DROP FOREIGN KEY `user_creator`;
ALTER TABLE relationship DROP FOREIGN KEY `user_who_changed_user`;
ALTER TABLE relationship DROP FOREIGN KEY `user_who_retired_this_user`;
ALTER TABLE relationship DROP FOREIGN KEY `name for person`;
ALTER TABLE relationship DROP FOREIGN KEY `user_who_made_name`;
ALTER TABLE relationship DROP FOREIGN KEY `user_who_voided_name`;
ALTER TABLE relationship DROP FOREIGN KEY `encounter_changed_by`;
ALTER TABLE relationship DROP FOREIGN KEY `encounter_form`;
ALTER TABLE relationship DROP FOREIGN KEY `encounter_ibfk_1`;
ALTER TABLE relationship DROP FOREIGN KEY `encounter_location`;
ALTER TABLE relationship DROP FOREIGN KEY `encounter_patient`;
ALTER TABLE relationship DROP FOREIGN KEY `encounter_provider`;
ALTER TABLE relationship DROP FOREIGN KEY `encounter_type_id`;
ALTER TABLE relationship DROP FOREIGN KEY `user_who_voided_encounter`;
ALTER TABLE relationship DROP FOREIGN KEY `discontinued_because`;
ALTER TABLE relationship DROP FOREIGN KEY `obs_for_order`;
ALTER TABLE relationship DROP FOREIGN KEY `order_creator`;
ALTER TABLE relationship DROP FOREIGN KEY `order_for_patient`;
ALTER TABLE relationship DROP FOREIGN KEY `orderer_not_drug`;
ALTER TABLE relationship DROP FOREIGN KEY `orders_in_encounter`;
ALTER TABLE relationship DROP FOREIGN KEY `type_of_order`;
ALTER TABLE relationship DROP FOREIGN KEY `user_who_discontinued_order`;
ALTER TABLE relationship DROP FOREIGN KEY `user_who_voided_order`;
ALTER TABLE relationship DROP FOREIGN KEY `answer_concept`;
ALTER TABLE relationship DROP FOREIGN KEY `answer_concept_drug`;
ALTER TABLE relationship DROP FOREIGN KEY `encounter_observations`;
ALTER TABLE relationship DROP FOREIGN KEY `obs_concept`;
ALTER TABLE relationship DROP FOREIGN KEY `obs_enterer`;
ALTER TABLE relationship DROP FOREIGN KEY `obs_grouping_id`;
ALTER TABLE relationship DROP FOREIGN KEY `obs_location`;
ALTER TABLE relationship DROP FOREIGN KEY `obs_name_of_coded_value`;
ALTER TABLE relationship DROP FOREIGN KEY `obs_order`;
ALTER TABLE relationship DROP FOREIGN KEY `person_obs`;
ALTER TABLE relationship DROP FOREIGN KEY `user_who_voided_obs`;
ALTER TABLE relationship DROP FOREIGN KEY `patient_in_program`;
ALTER TABLE relationship DROP FOREIGN KEY `patient_program_creator`;
ALTER TABLE relationship DROP FOREIGN KEY `program_for_patient`;
ALTER TABLE relationship DROP FOREIGN KEY `user_who_changed`;
ALTER TABLE relationship DROP FOREIGN KEY `user_who_voided_patient_program`;
ALTER TABLE relationship DROP FOREIGN KEY `patient_program_for_state`;
ALTER TABLE relationship DROP FOREIGN KEY `patient_state_changer`;
ALTER TABLE relationship DROP FOREIGN KEY `patient_state_creator`;
ALTER TABLE relationship DROP FOREIGN KEY `patient_state_voider`;
ALTER TABLE relationship DROP FOREIGN KEY `state_for_patient`;
ALTER TABLE relationship DROP FOREIGN KEY `address_for_person`;
ALTER TABLE relationship DROP FOREIGN KEY `patient_address_creator`;
ALTER TABLE relationship DROP FOREIGN KEY `patient_address_void`;
ALTER TABLE relationship DROP FOREIGN KEY `fk_rails_09e680ca40`;
ALTER TABLE relationship DROP FOREIGN KEY `person_a`;
ALTER TABLE relationship DROP FOREIGN KEY `person_b`;
ALTER TABLE relationship DROP FOREIGN KEY `relation_creator`;
DROP INDEX relation_creator ON relationship;
ALTER TABLE relationship DROP FOREIGN KEY `relation_voider`;
DROP INDEX relation_voider ON relationship;
ALTER TABLE relationship DROP FOREIGN KEY `relationship_type_id`;
ALTER TABLE users
ADD CONSTRAINT `fk_rails_fa67535741`
FOREIGN KEY (`person_id`)
REFERENCES person (`person_id`);
ALTER TABLE users
ADD CONSTRAINT `person_id_for_user`
FOREIGN KEY (`person_id`)
REFERENCES person (`person_id`);
ALTER TABLE users
ADD CONSTRAINT `user_creator`
FOREIGN KEY (`creator`, `site_id`)
REFERENCES users (`user_id`, `site_id`);
ALTER TABLE users
ADD CONSTRAINT `user_who_changed_user`
FOREIGN KEY (`changed_by`, `site_id`)
REFERENCES users (`user_id`, `site_id`);
ALTER TABLE users
ADD CONSTRAINT `user_who_retired_this_user`
FOREIGN KEY (`retired_by`, `site_id`)
REFERENCES users (`user_id`, `site_id`);
ALTER TABLE person_name
ADD CONSTRAINT `name for person`
FOREIGN KEY (`person_id`)
REFERENCES person (`person_id`);
ALTER TABLE person_name
ADD CONSTRAINT `user_who_made_name`
FOREIGN KEY (`creator`, `site_id`)
REFERENCES users (`user_id`, `site_id`);
ALTER TABLE person_name
ADD CONSTRAINT `user_who_voided_name`
FOREIGN KEY (`voided_by`, `site_id`)
REFERENCES users (`user_id`, `site_id`);
ALTER TABLE encounter
ADD CONSTRAINT `encounter_changed_by`
FOREIGN KEY (`changed_by`, `site_id`)
REFERENCES users (`user_id`, `site_id`);
ALTER TABLE encounter
ADD CONSTRAINT `encounter_form`
FOREIGN KEY (`form_id`)
REFERENCES form (`form_id`);
ALTER TABLE encounter
ADD CONSTRAINT `encounter_ibfk_1`
FOREIGN KEY (`creator`, `site_id`)
REFERENCES users (`user_id`, `site_id`);
ALTER TABLE encounter
ADD CONSTRAINT `encounter_location`
FOREIGN KEY (`location_id`)
REFERENCES location (`location_id`);
ALTER TABLE encounter
ADD CONSTRAINT `encounter_patient`
FOREIGN KEY (`patient_id`)
REFERENCES patient (`patient_id`);
ALTER TABLE encounter
ADD CONSTRAINT `encounter_provider`
FOREIGN KEY (`provider_id`)
REFERENCES person (`person_id`);
ALTER TABLE encounter
ADD CONSTRAINT `encounter_type_id`
FOREIGN KEY (`encounter_type`)
REFERENCES encounter_type (`encounter_type_id`);
ALTER TABLE encounter
ADD CONSTRAINT `user_who_voided_encounter`
FOREIGN KEY (`voided_by`, `site_id`)
REFERENCES users (`user_id`, `site_id`);
ALTER TABLE orders
ADD CONSTRAINT `discontinued_because`
FOREIGN KEY (`discontinued_reason`)
REFERENCES concept (`concept_id`);
ALTER TABLE orders
ADD CONSTRAINT `obs_for_order`
FOREIGN KEY (`obs_id`, `site_id`)
REFERENCES obs (`obs_id`, `site_id`);
ALTER TABLE orders
ADD CONSTRAINT `order_creator`
FOREIGN KEY (`creator`, `site_id`)
REFERENCES users (`user_id`, `site_id`);
ALTER TABLE orders
ADD CONSTRAINT `order_for_patient`
FOREIGN KEY (`patient_id`)
REFERENCES patient (`patient_id`);
ALTER TABLE orders
ADD CONSTRAINT `orderer_not_drug`
FOREIGN KEY (`orderer`, `site_id`)
REFERENCES users (`user_id`, `site_id`);
ALTER TABLE orders
ADD CONSTRAINT `orders_in_encounter`
FOREIGN KEY (`encounter_id`, `site_id`)
REFERENCES encounter (`encounter_id`, `site_id`);
ALTER TABLE orders
ADD CONSTRAINT `type_of_order`
FOREIGN KEY (`order_type_id`)
REFERENCES order_type (`order_type_id`);
ALTER TABLE orders
ADD CONSTRAINT `user_who_discontinued_order`
FOREIGN KEY (`discontinued_by`, `site_id`)
REFERENCES users (`user_id`, `site_id`);
ALTER TABLE orders
ADD CONSTRAINT `user_who_voided_order`
FOREIGN KEY (`voided_by`, `site_id`)
REFERENCES users (`user_id`, `site_id`);
ALTER TABLE obs
ADD CONSTRAINT `answer_concept`
FOREIGN KEY (`value_coded`)
REFERENCES concept (`concept_id`);
ALTER TABLE obs
ADD CONSTRAINT `answer_concept_drug`
FOREIGN KEY (`value_drug`)
REFERENCES drug (`drug_id`);
ALTER TABLE obs
ADD CONSTRAINT `encounter_observations`
FOREIGN KEY (`encounter_id`, `site_id`)
REFERENCES encounter (`encounter_id`, `site_id`);
ALTER TABLE obs
ADD CONSTRAINT `obs_concept`
FOREIGN KEY (`concept_id`)
REFERENCES concept (`concept_id`);
ALTER TABLE obs
ADD CONSTRAINT `obs_enterer`
FOREIGN KEY (`creator`, `site_id`)
REFERENCES users (`user_id`, `site_id`);
ALTER TABLE obs
ADD CONSTRAINT `obs_grouping_id`
FOREIGN KEY (`obs_group_id`, `site_id`)
REFERENCES obs (`obs_id`, `site_id`);
ALTER TABLE obs
ADD CONSTRAINT `obs_location`
FOREIGN KEY (`location_id`)
REFERENCES location (`location_id`);
ALTER TABLE obs
ADD CONSTRAINT `obs_name_of_coded_value`
FOREIGN KEY (`value_coded_name_id`)
REFERENCES concept_name (`concept_name_id`);
ALTER TABLE obs
ADD CONSTRAINT `obs_order`
FOREIGN KEY (`order_id`, `site_id`)
REFERENCES orders (`order_id`, `site_id`);
ALTER TABLE obs
ADD CONSTRAINT `person_obs`
FOREIGN KEY (`person_id`)
REFERENCES person (`person_id`);
ALTER TABLE obs
ADD CONSTRAINT `user_who_voided_obs`
FOREIGN KEY (`voided_by`, `site_id`)
REFERENCES users (`user_id`, `site_id`);
ALTER TABLE patient_program
ADD CONSTRAINT `patient_in_program`
FOREIGN KEY (`patient_id`)
REFERENCES patient (`patient_id`);
ALTER TABLE patient_program
ADD CONSTRAINT `patient_program_creator`
FOREIGN KEY (`creator`, `site_id`)
REFERENCES users (`user_id`, `site_id`);
ALTER TABLE patient_program
ADD CONSTRAINT `program_for_patient`
FOREIGN KEY (`program_id`)
REFERENCES program (`program_id`);
ALTER TABLE patient_program
ADD CONSTRAINT `user_who_changed`
FOREIGN KEY (`changed_by`, `site_id`)
REFERENCES users (`user_id`, `site_id`);
ALTER TABLE patient_program
ADD CONSTRAINT `user_who_voided_patient_program`
FOREIGN KEY (`voided_by`, `site_id`)
REFERENCES users (`user_id`, `site_id`);
ALTER TABLE patient_state
ADD CONSTRAINT `patient_program_for_state`
FOREIGN KEY (`patient_program_id`, `site_id`)
REFERENCES patient_program (`patient_program_id`, `site_id`);
ALTER TABLE patient_state
ADD CONSTRAINT `patient_state_changer`
FOREIGN KEY (`changed_by`, `site_id`)
REFERENCES users (`user_id`, `site_id`);
ALTER TABLE patient_state
ADD CONSTRAINT `patient_state_creator`
FOREIGN KEY (`creator`, `site_id`)
REFERENCES users (`user_id`, `site_id`);
ALTER TABLE patient_state
ADD CONSTRAINT `patient_state_voider`
FOREIGN KEY (`voided_by`, `site_id`)
REFERENCES users (`user_id`, `site_id`);
ALTER TABLE patient_state
ADD CONSTRAINT `state_for_patient`
FOREIGN KEY (`state`)
REFERENCES program_workflow_state (`program_workflow_state_id`);
ALTER TABLE person_address
ADD CONSTRAINT `address_for_person`
FOREIGN KEY (`person_id`)
REFERENCES person (`person_id`);
ALTER TABLE person_address
ADD CONSTRAINT `patient_address_creator`
FOREIGN KEY (`creator`, `site_id`)
REFERENCES users (`user_id`, `site_id`);
ALTER TABLE person_address
ADD CONSTRAINT `patient_address_void`
FOREIGN KEY (`voided_by`, `site_id`)
REFERENCES users (`user_id`, `site_id`);
ALTER TABLE pharmacy_batches
ADD CONSTRAINT `fk_rails_09e680ca40`
FOREIGN KEY (`location_id`)
REFERENCES location (`location_id`);
ALTER TABLE relationship
ADD CONSTRAINT `person_a`
FOREIGN KEY (`person_a`)
REFERENCES person (`person_id`);
ALTER TABLE relationship
ADD CONSTRAINT `person_b`
FOREIGN KEY (`person_b`)
REFERENCES person (`person_id`);
ALTER TABLE relationship
ADD CONSTRAINT `relation_creator`
FOREIGN KEY (`creator`, `site_id`)
REFERENCES users (`user_id`, `site_id`);
ALTER TABLE relationship
ADD CONSTRAINT `relation_voider`
FOREIGN KEY (`voided_by`, `site_id`)
REFERENCES users (`user_id`, `site_id`);
ALTER TABLE relationship
ADD CONSTRAINT `relationship_type_id`
FOREIGN KEY (`relationship`)
REFERENCES relationship_type (`relationship_type_id`);
