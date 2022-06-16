defmodule DbserviceWeb.UserController do
  use DbserviceWeb, :controller

  alias Dbservice.Users
  alias Dbservice.Users.User

  action_fallback DbserviceWeb.FallbackController

  use PhoenixSwagger

  def swagger_definitions do
    %{
      UserSingle:
        swagger_schema do
          title("User")
          description("A user in the application")

          properties do
            first_name(:string, "First name")
            last_name(:string, "Last name")
            email(:string, "Email")
            phone(:string, "Phone number")
            gender(:string, "Gender")
            address(:string, "Address")
            city(:string, "City")
            district(:string, "District")
            state(:string, "State")
            pincode(:string, "Pin code")
            role(:string, "User role")
          end

          example(%{
            first_name: "First name",
            last_name: "Last name",
            email: "Email",
            phone: "Phone number",
            gender: "Gender",
            address: "Address",
            city: "City",
            district: "District",
            state: "State",
            pincode: "Pin code",
            role: "User role"
          })
        end,
      User:
        swagger_schema do
          title("Users")
          description("A user in the application")

          properties do
            data(Schema.ref(:UserSingle))
          end
        end,
      Users:
        swagger_schema do
          title("Users")
          description("All users in the application")
          type(:array)
          items(Schema.ref(:UserSingle))
        end
    }
  end

  swagger_path :index do
    get("/api/user")
    response(200, "OK", Schema.ref(:Users))
  end

  def index(conn, _params) do
    user = Users.list_all_users()
    render(conn, "index.json", user: user)
  end

  swagger_path :create do
    post("/api/user")

    parameters do
      data(:body, Schema.ref(:UserSingle), "User to create", required: true)
    end

    response(201, "Created", Schema.ref(:User))
  end

  def create(conn, request) do
    with {:ok, %User{} = user} <- Users.create_user(request) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.user_path(conn, :show, user))
      |> render("show.json", user: user)
    end
  end

  swagger_path :show do
    get("/api/user/{userId}")

    parameters do
      userId(:path, :integer, "The id of the user", required: true)
    end

    response(200, "OK", Schema.ref(:User))
  end

  def show(conn, %{"id" => id}) do
    user = Users.get_user!(id)
    render(conn, "show.json", user: user)
  end

  swagger_path :update do
    patch("/api/user/{userId}")
    response(200, "OK")
  end

  def update(conn, %{"id" => id, "user" => user_params}) do
    user = Users.get_user!(id)

    with {:ok, %User{} = user} <- Users.update_user(user, user_params) do
      render(conn, "show.json", user: user)
    end
  end

  # swagger_path :delete do
  #   delete "/api/user/{userId}"
  #   response 200, "OK"
  # end

  def delete(conn, %{"id" => id}) do
    user = Users.get_user!(id)

    with {:ok, %User{}} <- Users.delete_user(user) do
      send_resp(conn, :no_content, "")
    end
  end

  def update_batches(conn, %{"id" => user_id, "batch_ids" => batch_ids})
      when is_list(batch_ids) do
    with {:ok, %User{} = user} <- Users.update_batches(user_id, batch_ids) do
      render(conn, "show.json", user: user)
    end
  end
end
