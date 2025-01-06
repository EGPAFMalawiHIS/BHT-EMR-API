#!/bin/bash

usage() {
  echo "Usage: $0 ENVIRONMENT"
  echo
  echo "ENVIRONMENT should be: development|test|production"
}

ENV=$1

if [ -z "$ENV" ]; then
  usage
  exit 255
fi

set -x # turns on stacktrace mode which gives useful debug information

export RAILS_ENV=$ENV
rails db:environment:set RAILS_ENV=$ENV

set +x # turns off stacktrace mode
# Load database configuration using Rails
CONFIG=$(rails runner "require 'yaml'; require 'erb'; puts YAML.safe_load(ERB.new(File.read('config/database.yml')).result, aliases: true).to_json")

DB_CONFIG=$(echo $CONFIG | jq -r --arg env "$ENV" '.[$env]["primary"] // .[$env] // empty')

USERNAME=$(echo $DB_CONFIG | jq -r '.username')
PASSWORD=$(echo $DB_CONFIG | jq -r '.password')
DATABASE=$(echo $DB_CONFIG | jq -r '.database')
HOST=$(echo $DB_CONFIG | jq -r '.host')
PORT=$(echo $DB_CONFIG | jq -r '.port')

# Only update metadata if migration is successful
rails db:migrate && {
  for sql_file in db/sql/openmrs_metadata_1_7.sql \
                  db/sql/bart2_views_schema_additions.sql \
                  db/initial_setup/anc2_schema_additions.sql \
                  db/sql/moh_regimens_v2021.sql \
                  db/sql/drug_cms_metadata.sql \
                  db/sql/ntp_regimens.sql; do
    mysql --host=$HOST --port=$PORT --user=$USERNAME --password=$PASSWORD $DATABASE < $sql_file
  done
}

