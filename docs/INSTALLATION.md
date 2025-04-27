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

### Recommended Versions

For development, we recommend using the following versions:

- Elixir: 1.14.2
- Erlang/OTP: 25

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
    BEARER_TOKEN="your_bearer_token"
    PATH_TO_CREDENTIALS="/full/path/to/your/service-account.json"
    ```

   - `BEARER_TOKEN` is used for API authentication
   - `PATH_TO_CREDENTIALS` should point to the absolute path of your Google Cloud service account JSON file

### Google Cloud Service Account Setup

For features that interact with Google services (like importing data from Google Sheets):

1. Create a service account from the Google Cloud Console
2. Generate a new key for this service account and download the JSON credentials file
3. Place this file in a secure location and set the `PATH_TO_CREDENTIALS` environment variable to its absolute path
4. To import data from a Google Sheet, you need to share the sheet with the service account:
   - Open your Google Sheet
   - Click "Share"
   - Paste the service account email (found in the credentials JSON file)
   - Give it Viewer access (read-only permissions are sufficient)

This configuration allows the application to authenticate with Google Cloud Platform and access shared Google Sheets for data import operations.

### Adding Data to Local Database

For **internal developers (employees)**, you can sync your local database with the production or staging database by running:

```bash
sh ./fetch-data.sh
```

This script pulls data from the production/staging environment into your local setup.

Note: Access to staging/production credentials is restricted to authorized personnel within the organization. Please contact the repository maintainers if you're an employee and require access.

For external contributors, please use the seed data to populate your local database:

```bash
mix run priv/repo/seeds.exs
```

This ensures you have the necessary data to develop and test the application locally without needing access to production data.

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
