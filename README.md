# Dbservice

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.setup`
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

### Deployment with Gigalixir
1. Install Gigalixir CLI
2. Login to Gigalixir account
```sh
gigalixir login
```
3. Verify account login
```sh
gigalixir account
```
4. Creating new gigalixir app (not needed if already done)
```sh
gigalixir create -n "af-db"
```
5. Scale up the application
```sh
gigalixir ps:scale --replicas=1
```
6. Configure env variables from Gigalixir dashboard
```sh
POOL_SIZE=2
DB_HOST='ecto://your-db-host/db-name'
PHX_HOST='af-db.gigalixirapp.com'
```
7. Run migrations
```sh
gigalixir run mix ecto.migrate
```
8. Check logs
```sh
gigalixir logs
```
## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
