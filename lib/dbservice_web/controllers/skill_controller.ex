defmodule DbserviceWeb.SkillController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Skills
  alias Dbservice.Skills.Skill

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Skill, as: SwaggerSchemaSkill

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaSkill.skill(),
      SwaggerSchemaSkill.skills()
    )
  end

  swagger_path :index do
    get("/api/skill")

    parameters do
      params(:query, :string, "The name of the Skill", required: false, name: "name")
    end

    response(200, "OK", Schema.ref(:Skills))
  end

  def index(conn, params) do
    query =
      from(m in Skill,
        order_by: [asc: m.id],
        offset: ^params["offset"],
        limit: ^params["limit"]
      )

    query =
      Enum.reduce(params, query, fn {key, value}, acc ->
        case String.to_existing_atom(key) do
          :offset -> acc
          :limit -> acc
          atom -> from(u in acc, where: field(u, ^atom) == ^value)
        end
      end)

    skill = Repo.all(query)
    render(conn, "index.json", skill: skill)
  end

  swagger_path :create do
    post("/api/skill")

    parameters do
      body(:body, Schema.ref(:Skill), "Skill to create", required: true)
    end

    response(201, "Created", Schema.ref(:Skill))
  end

  def create(conn, params) do
    case Skills.get_skill_by_name(params["name"]) do
      nil ->
        create_new_skill(conn, params)

      existing_skill ->
        update_existing_skill(conn, existing_skill, params)
    end
  end

  swagger_path :show do
    get("/api/skill/{skillId}")

    parameters do
      skillId(:path, :integer, "The id of the skill", required: true)
    end

    response(200, "OK", Schema.ref(:Skill))
  end

  def show(conn, %{"id" => id}) do
    skill = Skills.get_skill!(id)
    render(conn, "show.json", skill: skill)
  end

  swagger_path :update do
    patch("/api/skill/{skillId}")

    parameters do
      skillId(:path, :integer, "The id of the skill", required: true)
      body(:body, Schema.ref(:Skill), "Skill to create", required: true)
    end

    response(200, "Updated", Schema.ref(:Skill))
  end

  def update(conn, params) do
    skill = Skills.get_skill!(params["id"])

    with {:ok, %Skill{} = skill} <- Skills.update_skill(skill, params) do
      render(conn, "show.json", skill: skill)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/skill/{skillId}")

    parameters do
      skillId(:path, :integer, "The id of the Skill", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    skill = Skills.get_skill!(id)

    with {:ok, %Skill{}} <- Skills.delete_skill(skill) do
      send_resp(conn, :no_content, "")
    end
  end

  defp create_new_skill(conn, params) do
    with {:ok, %Skill{} = skill} <- Skills.create_skill(params) do
      conn
      |> put_status(:created)
      |> render("show.json", skill: skill)
    end
  end

  defp update_existing_skill(conn, existing_skill, params) do
    with {:ok, %Skill{} = skill} <- Skills.update_skill(existing_skill, params) do
      conn
      |> put_status(:ok)
      |> render("show.json", skill: skill)
    end
  end
end
