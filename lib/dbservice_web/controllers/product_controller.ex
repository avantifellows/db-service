defmodule DbserviceWeb.ProductController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Products
  alias Dbservice.Products.Product

  action_fallback DbserviceWeb.FallbackController

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Product, as: SwaggerSchemaProduct

  def swagger_definitions do
    # merge the required definitions in a pair at a time using the Map.merge/2 function
    Map.merge(SwaggerSchemaProduct.product(), SwaggerSchemaProduct.products())
  end

  swagger_path :index do
    get("/api/product")

    parameters do
      params(:query, :string, "The name the product", required: false, name: "name")
    end

    response(200, "OK", Schema.ref(:Products))
  end

  def index(conn, params) do
    query =
      from m in Product,
        order_by: [asc: m.id],
        offset: ^params["offset"],
        limit: ^params["limit"]

    query =
      Enum.reduce(params, query, fn {key, value}, acc ->
        case String.to_existing_atom(key) do
          :offset -> acc
          :limit -> acc
          atom -> from u in acc, where: field(u, ^atom) == ^value
        end
      end)

    product = Repo.all(query)
    render(conn, "index.json", product: product)
  end

  swagger_path :create do
    post("/api/product")

    parameters do
      body(:body, Schema.ref(:Product), "Product to create", required: true)
    end

    response(201, "Created", Schema.ref(:Product))
  end

  def create(conn, params) do
    with {:ok, %Product{} = product} <- Products.create_product(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.product_path(conn, :show, product))
      |> render("show.json", product: product)
    end
  end

  swagger_path :show do
    get("/api/product/{productId}")

    parameters do
      productId(:path, :integer, "The id of the product record", required: true)
    end

    response(200, "OK", Schema.ref(:Product))
  end

  def show(conn, %{"id" => id}) do
    product = Products.get_product!(id)
    render(conn, "show.json", product: product)
  end

  swagger_path :update do
    patch("/api/product/{productId}")

    parameters do
      productId(:path, :integer, "The id of the product record", required: true)
      body(:body, Schema.ref(:Product), "Product to create", required: true)
    end

    response(200, "Updated", Schema.ref(:Product))
  end

  def update(conn, params) do
    product = Products.get_product!(params["id"])

    with {:ok, %Product{} = product} <- Products.update_product(product, params) do
      render(conn, "show.json", product: product)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/product/{productId}")

    parameters do
      productId(:path, :integer, "The id of the product record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    product = Products.get_product!(id)

    with {:ok, %Product{}} <- Products.delete_product(product) do
      send_resp(conn, :no_content, "")
    end
  end
end
