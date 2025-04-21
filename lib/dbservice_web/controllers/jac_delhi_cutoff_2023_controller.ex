defmodule DbserviceWeb.JacDelhiCutoff2023Controller do
  use DbserviceWeb, :controller
  alias Dbservice.{Repo, JacDelhiCutoff2023}

  import Ecto.Query

  def index(conn, params) do
    query = from c in JacDelhiCutoff2023

    query =
      Enum.reduce(params, query, fn
        {"category", v}, acc when v != "" -> from c in acc, where: c.category == ^v
        {"gender", v}, acc when v != "" -> from c in acc, where: c.gender == ^v
        {"defense", v}, acc when v != "" ->
          val = v in [true, "true", 1, "1"]
          from c in acc, where: c.defense == ^val
        {"pwd", v}, acc when v != "" ->
          val = v in [true, "true", 1, "1"]
          from c in acc, where: c.pwd == ^val
        {"state", v}, acc when v != "" -> from c in acc, where: c.state == ^v
        {"rank", v}, acc when v != "" -> from c in acc, where: c.closing_rank >= ^String.to_integer(v)
        _, acc -> acc
      end)

    data = Repo.all(query)
    json(conn, data)
  end
end
