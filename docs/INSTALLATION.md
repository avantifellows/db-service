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

- Elixir: 1.18.4
- Erlang/OTP: 27.0

There are several ways to install these specific versions:

1. **Using Version Managers (Recommended)**
   - Visit [Version Managers documentation](https://elixir-lang.org/install.html#version-managers)
   - Popular version managers include asdf and kerl

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

## Tailwind CSS Setup

This project already has Tailwind CSS configured and ready to use. You only need to install the Tailwind binary.

### Installation
Since Tailwind is already configured in this project, you only need to run:

```bash
mix deps.get
mix tailwind.install
```

That's it! Tailwind CSS is now ready to use in your Phoenix application.

## Asset Management

### Production Asset Compilation
To compile and optimize assets for production, run:

```bash
mix assets.deploy
```

This command performs the following operations:
1. **`tailwind dbservice --minify`** - Compiles and minifies Tailwind CSS
2. **`esbuild default --minify`** - Compiles and minifies JavaScript with esbuild
3. **`phx.digest`** - Generates digested asset files with fingerprints for cache busting

## Environment Configuration

This application requires specific environment variables to be configured for proper functionality.

### Setup Environment Variables

1. **Copy the example environment file:**
  ```bash
  cp config/.env.example config/.env
  ```

2. **Configure the required variables in your `config/.env` file:**
  ```bash
  BEARER_TOKEN="your_bearer_token"
  PATH_TO_CREDENTIALS="/full/path/to/your/service-account.json"
  ```

  - `BEARER_TOKEN` is used for API authentication.
  - `PATH_TO_CREDENTIALS` should point to the absolute path of your Google Cloud service account JSON file.

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

## Adding Data to Local Database

For **internal developers (employees)**, you can sync your local database with the production or staging database by running:

```bash
sh ./fetch-data.sh
```

This script pulls data from the production/staging environment into your local setup.

**Note:** Access to staging/production credentials is restricted to authorized personnel within the organization. Please contact the repository maintainers if you're an employee and require access.

For external contributors, please use the seed data to populate your local database:

```bash
mix run priv/repo/seeds.exs
```

This ensures you have the necessary data to develop and test the application locally without needing access to production data.


## Editor Support

For enhanced development experience with Elixir, consider installing [`ElixirLS: Elixir support and debugger`](https://marketplace.visualstudio.com/items?itemName=JakeBecker.elixir-ls) from the Visual Studio Marketplace.

## Support Matrix

|  OTP Versions   | Elixir Versions | Supports ElixirLS |                          Issue(s)                          |
| :-------------: | :-------------: | :---------------: | :--------------------------------------------------------: |
|      any        |     <= 1.13     |        No         |              Broken, no support for required APIs                  |
|      22         |       1.13      |        ?        |         Erlang docs not working (requires EIP 48), May still work but no longer supported          |
|      23         |       1.13   |        ?        |          May still work but no longer supported                            |
|      24         |       1.13   |        ?        |          May still work but no longer supported                            |
|      25         |      1.13.4  |        ?        |         May still work but no longer supported                            |
|      23         |       1.14   |        Yes        |                            None                            |
|      24         |   1.14 - 1.16   |        Yes        |                            None                            |
|      25         |  1.14 - 1.18  |        Yes        |                            None                            |
| 26.0.0 - 26.0.1 |       any       |        No         | [#886](https://github.com/elixir-lsp/elixir-ls/issues/886) |
| 26.0.2 - 26.1.2 |  1.14.5 - 1.18  |    *nix only      | [#927](https://github.com/elixir-lsp/elixir-ls/issues/927), [#1023](https://github.com/elixir-lsp/elixir-ls/issues/1023) |
|   >= 26.2.0     |  1.14.5 - 1.18  |        Yes        |                            None                            |
|      any        |     1.15.5      |        Yes        |  Broken formatter [#975](https://github.com/elixir-lsp/elixir-ls/issues/975) |
|      27         |    1.17 - 1.18  |        Yes        |                            None                            |
|      28         |      1.18.4     |        Yes        |                            None                            |


