# HIS EMR API

Table of Contents
=================

- [HIS EMR API](#his-emr-api)
  - [Requirements](#requirements)
  - [Setting up](#setting-up)
    - [Configuration](#configuration)
    - [Setting up rails](#setting-up-rails)
    - [Setting up Production mode](#setting-up-production-mode)
      - [Database](#database)
        - [Using an existing database](#using-an-existing-database)
        - [Using an empty database](#using-an-empty-database)
      - [DDE](#dde)
    - [Updating Metadata](#updating-metadata)
    - [EMC to POC](#emc-to-poc)
    - [AIT Intergration](#ait-intergration)
    - [Running the API](#running-the-api)
  - [Creating a Service](#creating-a-service)
  - [Raw Data Store](#raw-data-store)
  - [For developers](#for-developers)
    - [Documentation](#documentation)
      - [Building the Documentation](#building-the-documentation)
    - [Testing](#testing)
    - [Coding style/standards](#coding-stylestandards)
    - [Useful (recommended) tools for development](#useful-recommended-tools-for-development)
    - [Dev Container](#dev-container)
    - [Data Cleaning](#data-cleaning)
   - [Contributors](#contributors)

## Requirements

The following are required to run the API:

- Ruby 3.2+
- Rails 7.0+
- MySQL 5.6+

The following dependencies are also required for some operations,
however the API can do without:

- DDE3 - Grab it from [here](https://github.com/BaobabHealthTrust/Demographics-Data-Exchange)

In addition to the requirements above, you need the following for development.

- [Postman](https://www.getpostman.com) - Used for editing documentation
- [Postmanerator](https://github.com/aubm/postmanerator) - Used for building the documentation

[Back to top](#table-of-contents)

## Setting up

All the operations below assume your current working directory is the
project directory. Navigate to that if you are some place else.

### Configuration

### Setting up rails

Install the required gems like so:

```sh
bundle install
```

For sites that are operating offline, you can use the following command to install the required gems

```sh
bundle install --local
```

### Setting up Production mode
```sh
bin/setup_production_mode.sh 
```

Incase this does not run you might want to make it executable and you can achieve that by doing this
```sh
chmod +x bin/setup_production_mode.sh 
```

#### Database

The API uses an [Openmrs 1.7](https://openmrs.org/2010/11/openmrs-1-7-now-available/)
compatible database as a base for its own database. If you have an ART database
dump available you can (and should) use that. The API was designed to hook
into an already existing database.

Copy the configuration file from `config/database.yml.example` to
`config/database.yml`. Edit the new file to point to your database.

```sh
$ cp config/database.yml.example config/database.yml
...
$ vim config/database.yml   # Edit configuration
...
```

##### Using an existing database

1. Load metadata into your mysql database as follows:

    ```bash
    cat db/sql/openmrs_metadata_1_7.sql | mysql -u <username> -p <database_name>
    ```

2. Run migrations:

    ```bash
    bin/rails db:migrate
    ```

3. Load moh regimen tables into your database:

    ```bash
    cat db/sql/add_regimens_13_and_above.sql | mysql -u <username> -p <database>
    ```
4. For TB app: Load ntp regimen tables into your database:

    ```bash
    cat db/sql/ntp_regimens.sql | mysql -u <username> -p <database>
    ```

5. Set up the test database as follows:

    ```bash
    bin/initial_database_setup.sh test mpc
    ```

6. Run the following to run tests (if all goes well you are good to go):

    ```bash
    bin/rspec
    ```

##### Using an empty database

1. Run the following commands to set up your development and test databases.

    ```sh
    bin/initial_database_setup.sh production mpc && bin/initial_database_setup.sh development mpc && bin/initial_database_setup.sh test mpc
    ```

2. Run test suite as follows:

    ```bash
    bin/rspec
    ```

#### DDE

- Configuration

Copy `config/application.yml.example` to `config/application.yml`. Edit all the
`dde_*` parameters to point to a running DDE instance.

```sh
$ cp config/application.yml.example config/application.yml
...
$ vim config/application.yml
...
```

- Enabling DDE

To enable DDE you have to set the global_property `dde_enabled` to 1. Global
properties can be updated through the `properties` end-point or directly in
the database on the global_property table. Below is how you can do it on
a UNIX terminal.

First log into the API:

```sh
curl -X POST -H "Content-Type: application/json" -d '{
    "username": "admin",
    "password": "test"
}' "http://127.0.0.1:3000/api/v1/auth/login"
```

The command above should give a response similar to the following:

```json
    {
        "authorization": {
            "token": "AiJViSpF3spb",
            "expiry_time": "2018-08-28T11:01:55.501+02:00"
        }
    }
```

Take token above and use it the following command as a parameter to
the Authorization header as:

```sh
curl -X POST -H "Authorization: AiJViSpF3spb" -H "Content-Type: application/json" -d '{
    "property": "dde_enabled",
    "value": "true"
}' "http://127.0.0.1:3000/api/v1/properties"
```

### Updating Metadata
- Facilities
```bash
./bin/update_art_metadata.sh [production|development|test]
```
You will have to choose the environment you want to update the metadata for.

- Developers
To add metadata into the system
```bash
bin/dump_metadata.sh
```

Commit the changes to the repository. And as always make sure you create a PR to be reviewed.


### EMC to POC
These are the instructions of migrating data for sites that have changed from an e-Mastercard(EMC) to Point of Care(POC).
Open a terminal and navigate to the API application folder. On the root of the application folder run this command in your terminal

```bash
rails r ./bin/vl_migration.rb
```

Once this process completes a csv file will be created on the root of the application folder. The file name will have the following
structure:

```bash
emc_poc_migration_dateMigrationWasRun.csv
```

An example of the file output by this process would be
```bash
emc_poc_migration_20220816.csv
```

The migration will skip certain results if they are blank/without value. You can find this list in the following file structure:
```bash
emc_poc_migration_skipped_yearmonthday.csv
```

An example of the file output by this process would be
```bash
emc_poc_migration_skipped_20220816.csv
```

The file will indicate the result date and the client ARV number which can be used for BDE purposes

### AIT Intergration
To intergrate to AIT and send HTS patient data, follow the steps below

-   Copy and populate the AIT config file
  
```bash
cp ./config/ait.yml.example ./config/ait.yml
```

[SETUP AIT CONFIGURATION](db/hts_metadata/README.md)


### Running the API

You can do the following (don't run it like this in production):

```sh
bin/rails server
```

[Back to top](#table-of-contents)

## Creating a Service
Instead of manually running the server, you can create a service to run the server. This is useful when you want to run the server in the background. To create a service, run the following command:

```sh
sudo chmod +x ./bin/create_service.sh && ./bin/create_service.sh
```

Please follow the instructions provided by the script. Once the service is created, you can start, stop, and restart the service using the following commands:

```sh
sudo service emr-api start
sudo service emr-api stop
sudo service emr-api restart
```

To check the status of the service, run the following command:

```sh
sudo service emr-api status
```

[Back to top](#table-of-contents)

## Raw Data Store

The BHT-EMR-API is capable of pushing data to the Raw Data Store.
More information on how to get it to do this can be found [here](./doc/rds/index.md)

[Back to top](#table-of-contents)

## For developers

### Documentation

If you need to build the documentation then you have to set up postman and
postmanerator. Set up postman by following the instructions provided
[here](https://www.getpostman.com). For postmanerator grab a binary for
your operating system from [here](https://github.com/aubm/postmanerator/releases).

#### Building the Documentation

To edit the documentation, fire up postman and then import the collection at
`doc/src/index.json`. Once done editing it in postman, export it back
as version 1 collection to the same path.

To build the documentation do the following:

```sh
postmanerator --collection=doc/src/index.json --output=public/index.html
```

A wrapper script for the above command is provided to make life easier.
Execute it like so:

```sh
bin/make_docs
```

You can view the documentation by opening `public/index.html` or hitting
`/index.html` on a running instance of the API.

### Testing

[RSpec](http://rspec.info) and [RSpec-rails](https://github.com/rspec/rspec-rails)
are used for unit/integration testing. Primarily tests are written as feature
tests for services (See coding style below), however in some cases unit tests are
done for small pieces that looks suspect.

A test database is require before anything else. Run the following to set up the
test database.

```sh
$ bin/initial_database_setup.sh test moh
...
```

WARNING: The command above will clobber the database set up for testing the
database configuration.

To run the tests, navigate to the project directory and run `bin/rspec`. You can
target a specific test by running `bin/rspec <path-to-test>`.

```sh
$ bin/rspec     # To run all tests
...
$ bin/rspec path/to/test    # To run specific test
...
```

### Coding style/standards

At a minimum try to stick to the following:

- Use 2 spaces (not tab configured to take 2 spaces) for indentation
- Methods should normally not exceed 12 lines (you can go beyond this with good reason)
- Prefer `&&/||` over `and/or`
- Error should never pass silently, if you handle an exception, log the error you just handled
- Related to the point above, avoid inline rescue statements
- Use guard statements when validating a variable, if you can't, consider moving the validation logic to a method
- Package your business logic in services where possible. These are located in `app/services` directory.
  Try to keep them [SOLID](https://en.wikipedia.org/wiki/SOLID) please.
- If you know it's a hack please leave a useful comment
- If what you wrote doesn't make sense, revise until it does else leave useful comments and a unit test
- If a file exceeds 120 lines, you better have a good reason as to why it is so
- This is Ruby, it shouldn't read like Java, see [Writing Beautiful Ruby](https://medium.com/the-renaissance-developer/idiomatic-ruby-1b5fa1445098)

See the following for more:

- [Rubocop style guide](https://github.com/rubocop-hq/ruby-style-guide)

### Useful (recommended) tools for development

- [Vscode](https://code.visualstudio.com/download) for editing
- Rubocop - you can use this to format your code and find/fix various [defect attractors](http://esr.ibiblio.org/?p=8042)
- If you use VSCode check out the following plugins [Ruby](https://marketplace.visualstudio.com/search?term=Ruby&target=VSCode), [Ruby-Rubocop](https://marketplace.visualstudio.com/search?term=Rubocop&target=VSCode&category=All%20categories&sortBy=Relevance), and [Rufo](https://marketplace.visualstudio.com/search?term=Rufo&target=VSCode&category=All%20categories&sortBy=Relevance), [Ruby Solargraph](https://marketplace.visualstudio.com/items?itemName=castwide.solargraph)

### Dev Container
* Install [Docker](https://docs.docker.com/get-docker/)
* Install [Docker Compose](https://docs.docker.com/compose/install/)
* We assume you are using VSCode as your editor
* Install the [Remote - Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension
* Open the project in VSCode
* Click on the green button at the bottom left of the window
* Select `Reopen in Container`
* Wait for the container to build
* Run `bash bin/container_start.sh` to setup the container and install dependencies. Only run this once unless you have rebuilt the container. If nothing happens after running this command, then you might want to execute the commands in the script manually.

**Note:** If you are using a dev container, then it comes with a pre-configured database and you don't need to run the migrations and seeds.

**Note:** Perks of using a dev container include:
* You don't need to install Ruby, Rails, MySQL, etc on your local machine
* You don't need to worry about setting up the database, migrations, seeds, etc
* You don't need to worry about setting up mysql client the container comes with it pre-installed
* You don't need to worry about setting up the environment variables, the container comes with them pre-configured
* You don't need to worry about setting up the storage, the container comes with it pre-configured
* You don't need to worry about setting up the locale, the container comes with it pre-configured
* You don't need to worry about setting up the gems, the container comes with them pre-installed

### Data Cleaning

- [ANC](/bin/ANC/README.md)

## Contributors
These are organizations that have contributed to the development of the HIS EMR API
<p>
    <img src="public/malawi.png" alt="Malawi Government" style="background: white !important;height:60px;padding: 5px;border-radius:1%" />
    <img src="public/PEPFAR.jpg" alt="PEPFAR" style="background: white !important;height:60px;padding: 5px; object-fit:fit;border-radius:1%;" />
    <img src="public/egpaf.png" alt="Elizabeth Glaser Pediatric AIDS Foundation" style="background: white !important;height:60px;padding: 5px; object-fit:fit;border-radius:1%;" />
    <img src="public/baobab.png" alt="Baobab Health Trust" style="background: white !important;height:60px;padding: 5px; object-fit:fit;border-radius:1%;" />
    <img src="public/LIN.jpg" alt="Luke International" style="background: white !important;height:60px;padding: 5px; object-fit:fit;border-radius:1%;" />
</p>


[Back to top](#table-of-contents)
