defmodule DbserviceWeb.CollegeController do
  @moduledoc """
  Handles HTTP requests for College resources.
  """
  use DbserviceWeb, :controller
  use PhoenixSwagger

  alias Dbservice.Colleges.College
  alias Dbservice.Repo
  alias DbserviceWeb.SwaggerSchema.College, as: CollegeSchema
  alias DbserviceWeb.SwaggerSchema.Common, as: SwaggerSchemaCommon

  action_fallback DbserviceWeb.FallbackController

  @doc """
  Returns the swagger definitions for the College schemas.
  """
  def swagger_definitions do
    Map.merge(
      CollegeSchema.college(),
      SwaggerSchemaCommon.group_ids()
    )
  end

  @doc """
  Swagger documentation for the index action.
  """
  swagger_path :index do
    get "/api/colleges"
    description "List all colleges"
    produces "application/json"
    parameter :query, :page, :integer, "Page number"
    parameter :query, :page_size, :integer, "Number of items per page"
    response 200, "Success", Schema.ref(:College)
  end

  @doc """
  Swagger documentation for the show action.
  """
  swagger_path :show do
    get "/api/colleges/{id}"
    description "Get a specific college"
    produces "application/json"
    parameter :path, :id, :integer, "College ID"
    response 200, "Success", Schema.ref(:College)
    response 404, "Not Found"
  end

  @doc """
  Swagger documentation for the create action.
  """
  swagger_path :create do
    post "/api/colleges"
    description "Create a new college"
    produces "application/json"
    consumes "application/json"
    parameter :body, :college, Schema.ref(:CollegeRequest), "College attributes"
    response 201, "Created", Schema.ref(:College)
    response 422, "Unprocessable Entity"
  end

  @doc """
  Swagger documentation for the update action.
  """
  swagger_path :update do
    patch "/api/colleges/{id}"
    description "Update a college"
    produces "application/json"
    consumes "application/json"
    parameter :path, :id, :integer, "College ID"
    parameter :body, :college, Schema.ref(:CollegeRequest), "College attributes"
    response 200, "Success", Schema.ref(:College)
    response 404, "Not Found"
    response 422, "Unprocessable Entity"
  end

  @doc """
  Swagger documentation for the delete action.
  """
  swagger_path :delete do
    delete "/api/colleges/{id}"
    description "Delete a college"
    parameter :path, :id, :integer, "College ID"
    response 204, "No Content"
    response 404, "Not Found"
  end

  @doc """
  Lists all colleges with pagination.

  ## Parameters
    - page: Page number (default: 1)
    - page_size: Number of items per page (default: 10, max: 100)
  """
  def index(conn, params) do
    with {:ok, page} <- validate_pagination_params(params) do
      page = College.list_colleges(page)
      render(conn, :index, page: page)
    end
  end

  @doc """
  Creates a new college.

  ## Parameters
    - college: Map containing college attributes
  """
  def create(conn, %{"college" => college_params}) do
    with {:ok, %College{} = college} <- College.create_college(college_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.college_path(conn, :show, college))
      |> render(:show, college: college)
    end
  end

  @doc """
  Shows a specific college by ID.

  ## Parameters
    - id: College ID
  """
  def show(conn, %{"id" => id}) do
    with %College{} = college <- College.get_college(id) do
      render(conn, :show, college: college)
    else
      nil -> {:error, :not_found, "College not found"}
    end
  end

  @doc """
  Updates a college.

  ## Parameters
    - id: College ID
    - college: Map containing updated college attributes
  """
  def update(conn, %{"id" => id, "college" => college_params}) do
    with %College{} = college <- College.get_college(id),
         {:ok, %College{} = updated_college} <- College.update_college(college, college_params) do
      render(conn, :show, college: updated_college)
    else
      nil -> {:error, :not_found, "College not found"}
      error -> error
    end
  end

  # Private helper functions

  defp validate_pagination_params(params) do
    page_number = String.to_integer(params["page"] || "1")
    page_size = String.to_integer(params["page_size"] || "10")

    cond do
      page_number < 1 -> {:error, :bad_request, "page must be greater than 0"}
      page_size < 1 -> {:error, :bad_request, "page_size must be greater than 0"}
      page_size > 100 -> {:error, :bad_request, "page_size must be less than or equal to 100"}
      true -> {:ok, %{page_number: page_number, page_size: page_size}}
    end
  rescue
    ArgumentError -> {:error, :bad_request, "Invalid pagination parameters"}
  end
end
