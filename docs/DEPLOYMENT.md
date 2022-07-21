# Deployment
This guide covers steps on setting up this repository on various cloud hosting providers.
  - [Gigalixir](#gigalixir)

## Gigalixir

### Pre-requisites
1. Install [Gigalixir CLI](https://gigalixir.readthedocs.io/en/latest/getting-started-guide.html#install-the-command-line-interface)
2. Verify installation using:
    ```sh
    gigalixir version
    ```
3. Configure your database server.
   - Create a new database for the application and log into the database.
   - Open the Postgres CLI and check the enabled extensions:
        ```sql
        SELECT * FROM pg_extension;
        ```
    - If the `uuid-ossp` module isn't showing up, then run the following command. We require this extension in order to support the Postgres' `uuid_generate_v4` function that auto-generate UUIDs.
        ```sql
        CREATE EXTENSION "uuid-ossp";
        ```

### Production
1. Login to Gigalixir account
    ```sh
    gigalixir login
    ```
3. Verify account login
    ```sh
    gigalixir account
    ```
4. Creating new gigalixir app (not needed if already done)
    ```sh
    gigalixir create -n "my-app"
    ```
5. Scale up the application
    ```sh
    gigalixir ps:scale --replicas=1
    ```
6. Configure env variables from Gigalixir dashboard
    ```sh
    POOL_SIZE=2
    DB_HOST='ecto://your-db-host/db-name'
    PHX_HOST='my-app.gigalixirapp.com'
    ```
7. Run migrations
    ```sh
    gigalixir run mix ecto.migrate
    ```
8. Check logs
    ```sh
    gigalixir logs
    ```
9. Wait for some time and then open the host in browser
    ```sh
    gigalixir open
    ```
10. Create a custom domain name
    ```sh
    gigalixir domains:add my-app.my-domain.com
    # replace with your domain name
    ```
11. Check domain name has been properly added
    ```sh
    gigalixir domains
    ```
12. Update your DNS configurations and add a CNAME configuration as given in the `gigalixir domains` command output.
13. Wait for some time and the app should be running on the updated domain name.
