# Installation

DB Service is built using the Phoenix framework which is based on Elixir programming language. Before setting up this project, there are certain tools required to be installed on your machine.

## Pre-requisites

Install the following packages using your favorite package manager. Links are provided for some

- [Install Elixir](https://elixir-lang.org/install.html#distributions)
  - Once installed, verify the installations using:

    ```sh
    elixir --version
    mix --version
    ```

- [Install Postgres](https://www.postgresql.org/download/)
  - Run the following steps to install Postgres on a Mac device

    ```
    brew install postgresql
    brew services start postgresql
    ```

  - Once installed, verify the installations using `postgres --version`. You should be able to see:

    ```
    postgres (PostgreSQL) 14.9 (Homebrew)
    ```

  - For Postgres, this app defaults to `postgres` as both the username and password. This can be edited in `config/dev.exs` file.
  - Create a new database for the application called `dbservice_dev`. You can do this by running the command: `createdb dbservice_dev`
  - You can also use interactive postgres terminal `psql`. To open database, use: `psql -d dbservice_dev`
  - Log into the database created.
  - Open the Postgres CLI and check the enabled extensions:

    ```sql
    SELECT * FROM pg_extension;
    ```

  - If the `uuid-ossp` module isn't showing up, then run the following command. We require this extension in order to support the Postgres' `uuid_generate_v4` function that auto-generate UUIDs.

    ```sql
    CREATE EXTENSION "uuid-ossp";
    ```

### Required Versions

The following versions are required for this project:

- Elixir: 1.14.2
- Erlang/OTP: 25

There are several ways to install these specific versions:

1. **Using Version Managers (Recommended)**
   - Visit [Version Managers documentation](https://elixir-lang.org/install.html#version-managers)
   - Popular version managers include asdf and kiex

2. **Using Install Scripts**
   - Visit [Install Scripts documentation](https://elixir-lang.org/install.html#install-scripts)
   - Download the install script for your operating system
   - Modify the script to specify version 1.14.2 before running

3. **Manual Installation**
   - Download the specific version zip file from [Elixir releases](https://elixir-lang.org/docs)
   - Extract the contents
   - Add the `bin` directory to your system's PATH

## Installation steps

Follow the steps below to set up the repo for development

1. Clone the repository and change the working directory

    ```sh
    git clone https://github.com/avantifellows/db-service.git
    cd db-service/
    ```

2. Start the Phoenix server:
   1. Install dependencies with `mix deps.get`
   2. Create and migrate your database with `mix ecto.setup`
   3. Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`
3. Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.
4. You can see Swagger docs at `http://localhost:4000/docs/swagger/index.html`.
5. Please verify that `localhost` is part of whitelisted domains. If not, you can create a file `db-service/config/.env` and add the following lines to it:

    ```
    WHITELISTED_DOMAINS="localhost"
    ```

### Adding data to local database

You can add data to local database by running `sh ./fetch-data.sh`. This will fetch data from production/staging database and sync with your local database. Please ask repository owners for the following credentials:

```production_db_host="xxx.rds.amazonaws.com"
production_db_name="xxx"
production_db_user="postgres"
production_db_password="xxx"
```

## Editor Support

For enhanced development experience with Elixir, consider installing [`ElixirLS: Elixir support and debugger`](https://marketplace.visualstudio.com/items?itemName=JakeBecker.elixir-ls) from the Visual Studio Marketplace.

### ElixirLS support matrix

|  OTP Versions   | Elixir Versions | Supports ElixirLS |
| :-------------: | :-------------: | :---------------: |
|      any        |     <= 1.12     |        No         |
|      22         |       1.12      |        Yes        |
|      23         |   1.12 - 1.14   |        Yes        |
|      24         |   1.12 - 1.16   |        Yes        |
|      25         |  1.13.4 - 1.16  |        Yes        |
| 26.0.0 - 26.0.1 |       any       |        No         |
| 26.0.2 - 26.1.2    |  1.14.5 - 1.16  |    *nix only      |
|   >= 26.2.0     |  1.14.5 - 1.16  |        Yes        |
|      any        |     1.15.5      |        Yes        |
