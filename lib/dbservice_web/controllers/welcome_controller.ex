defmodule DbserviceWeb.WelcomeController do
  use DbserviceWeb, :controller

  def index(conn, _params) do
    text(conn, "Welcome to Db Service!")
  end
end
