defmodule DbserviceWeb.JacDelhiCutoff2023Controller do
  use DbserviceWeb, :controller
  use PhoenixSwagger
  alias Dbservice.{Repo, JacDelhiCutoff2023}

  import Ecto.Query

 # added the swagger block for testing
  swagger_path :index do
    get("/api/jac_delhi_cutoff_2023")
    summary("Get JAC Delhi Cutoff 2023 data")
    description("Fetches cutoff data with optional filters for category, gender, defense, pwd, state, and rank.")

    parameters do
      category(:query, :string, "Category", required: false, enum: ["EWS", "Kashmiri Minority", "OBC", "General", "ST", "SC"])
    gender(:query, :string, "Gender", required: false, enum: ["Gender-Neutral", "Female-Only"])
    defense(:query, :boolean, "Defense", required: false, enum: [true, false])
    pwd(:query, :boolean, "PWD", required: false, enum: [true, false])
    state(:query, :string, "State", required: false, enum: ["Delhi", "Outside Delhi"])
    rank(:query, :integer, "Minimum closing rank", required: false)
    end

    response(200, "Success")
  end
  # --- End Swagger block ---

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