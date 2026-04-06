defmodule Dbservice.Products do
  @moduledoc """
  The Products context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Products.Product
  alias Dbservice.Groups.Group

  @doc """
  Returns the list of products.
  ## Examples
      iex> list_product()
      [%Product{}, ...]
  """
  def list_product do
    Repo.all(Product)
  end

  @doc """
  Gets a single product.
  Raises `Ecto.NoResultsError` if the Product does not exist.
  ## Examples
      iex> get_product!(123)
      %Product{}
      iex> get_product!(456)
      ** (Ecto.NoResultsError)
  """
  def get_product!(id), do: Repo.get!(Product, id)

  @doc """
  Gets a Product by product name and code.
  Raises `Ecto.NoResultsError` if the Product does not exist.
  ## Examples
      iex> get_product_by_name_and_code("a","b")
      %Product{}
      iex> get_product_by_name_and_code(1,1)
      ** (Ecto.NoResultsError)
  """
  def get_product_by_name_and_code(name, code) do
    Repo.get_by(Product, name: name, code: code)
  end

  @doc """
  Gets a product by code. Returns nil if not found.
  """
  def get_product_by_code(code) when is_binary(code) do
    code = String.trim(code)
    if code == "", do: nil, else: Repo.get_by(Product, code: code)
  end

  def get_product_by_code(_), do: nil

  @doc """
  Creates a product.
  ## Examples
      iex> create_product(%{field: value})
      {:ok, %Product{}}
      iex> create_product(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_product(attrs \\ %{}) do
    %Product{}
    |> Product.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:group, [%Group{type: "product", child_id: attrs["id"]}])
    |> Repo.insert()
  end

  @doc """
  Creates a product and its `group` row (child_id = product.id, type "product").
  Used by data import.
  """
  def create_product_from_import(attrs) when is_map(attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:product, Product.changeset(%Product{}, attrs))
    |> Ecto.Multi.insert(:group, fn %{product: p} ->
      Group.changeset(%Group{}, %{type: "product", child_id: p.id})
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{product: p}} -> {:ok, p}
      {:error, :product, changeset, _} -> {:error, changeset}
      {:error, :group, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Updates a product.
  ## Examples
      iex> update_product(product, %{field: new_value})
      {:ok, %Product{}}
      iex> update_product(product, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_product(%Product{} = product, attrs) do
    product
    |> Product.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a product.
  ## Examples
      iex> delete_product(product)
      {:ok, %Product{}}
      iex> delete_product(product)
      {:error, %Ecto.Changeset{}}
  """
  def delete_product(%Product{} = product) do
    Repo.delete(product)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking group changes.
  ## Examples
      iex> change_product(product)
      %Ecto.Changeset{data: %Product{}}
  """
  def change_product(%Product{} = product, attrs \\ %{}) do
    Product.changeset(product, attrs)
  end
end
