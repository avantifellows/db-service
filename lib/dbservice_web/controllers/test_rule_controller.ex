defmodule DbserviceWeb.TestRuleController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.TestRules
  alias Dbservice.TestRules.TestRule

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.TestRule, as: SwaggerSchemaTestRule

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaTestRule.test_rule(),
      SwaggerSchemaTestRule.test_rules()
    )
  end

  swagger_path :index do
    get("/api/test-rule")

    parameters do
      params(:query, :string, "The type of the test rule", required: false, name: "test_type")
      params(:query, :integer, "The exam id", required: false, name: "exam_id")
      params(:query, :integer, "Offset for pagination", required: false, name: "offset")
      params(:query, :integer, "Limit for pagination", required: false, name: "limit")
    end

    response(200, "OK", Schema.ref(:TestRules))
  end

  def index(conn, params) do
    query =
      from(tr in TestRule,
        order_by: [asc: tr.id],
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

    test_rules = Repo.all(query)
    render(conn, "index.json", test_rules: test_rules)
  end

  swagger_path :create do
    post("/api/test-rule")

    parameters do
      body(:body, Schema.ref(:TestRule), "TestRule to create", required: true)
    end

    response(201, "Created", Schema.ref(:TestRule))
  end

  def create(conn, params) do
    case Repo.get_by(TestRule, exam_id: params["exam_id"], test_type: params["test_type"]) do
      nil ->
        create_new_test_rule(conn, params)

      existing_test_rule ->
        update_existing_test_rule(conn, existing_test_rule, params)
    end
  end

  swagger_path :show do
    get("/api/test-rule/{testRuleId}")

    parameters do
      testRuleId(:path, :integer, "The id of the test_rule", required: true)
    end

    response(200, "OK", Schema.ref(:TestRule))
  end

  def show(conn, %{"id" => id}) do
    test_rule = TestRules.get_test_rule!(id)
    render(conn, "show.json", test_rule: test_rule)
  end

  swagger_path :update do
    patch("/api/test-rule/{testRuleId}")

    parameters do
      testRuleId(:path, :integer, "The id of the test_rule", required: true)
      body(:body, Schema.ref(:TestRule), "TestRule to update", required: true)
    end

    response(200, "Updated", Schema.ref(:TestRule))
  end

  def update(conn, params) do
    test_rule = TestRules.get_test_rule!(params["id"])

    with {:ok, %TestRule{} = test_rule} <- TestRules.update_test_rule(test_rule, params) do
      render(conn, "show.json", test_rule: test_rule)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/test-rule/{testRuleId}")

    parameters do
      testRuleId(:path, :integer, "The id of the test_rule", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    test_rule = TestRules.get_test_rule!(id)

    with {:ok, %TestRule{}} <- TestRules.delete_test_rule(test_rule) do
      send_resp(conn, :no_content, "")
    end
  end

  defp create_new_test_rule(conn, params) do
    with {:ok, %TestRule{} = test_rule} <- TestRules.create_test_rule(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/test-rule/#{test_rule}")
      |> render("show.json", test_rule: test_rule)
    end
  end

  defp update_existing_test_rule(conn, existing_test_rule, params) do
    with {:ok, %TestRule{} = test_rule} <- TestRules.update_test_rule(existing_test_rule, params) do
      conn
      |> put_status(:ok)
      |> render("show.json", test_rule: test_rule)
    end
  end
end
