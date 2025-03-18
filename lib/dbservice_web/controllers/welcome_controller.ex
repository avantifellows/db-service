defmodule DbserviceWeb.WelcomeController do
  use DbserviceWeb, :controller

  def index(conn, _params) do
    text(conn, "Welcome to Database Service!")
  end
end
