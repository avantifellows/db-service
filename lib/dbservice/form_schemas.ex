defmodule Dbservice.FormSchemas do
  @moduledoc """
  The Groups context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.FormSchemas.FormSchema

  @doc """
  Returns the list of form_schema.
  ## Examples
      iex> list_form_schema()
      [%FormSchema{}, ...]
  """
  def list_form_schema do
    Repo.all(FormSchema)
  end

  @doc """
  Gets a single form_schema.
  Raises `Ecto.NoResultsError` if the FormSchema does not exist.
  ## Examples
      iex> get_form_schema!(123)
      %FormSchema{}
      iex> get_form_schema!(456)
      ** (Ecto.NoResultsError)
  """
  def get_form_schema!(id), do: Repo.get!(FormSchema, id)

  @doc """
  Creates a form_schema.
  ## Examples
      iex> create_form_schema(%{field: value})
      {:ok, %FormSchema{}}
      iex> create_form_schema(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_form_schema(attrs \\ %{}) do
    %FormSchema{}
    |> FormSchema.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a form_schema.
  ## Examples
      iex> update_form_schema(group, %{field: new_value})
      {:ok, %FormSchema{}}
      iex> update_form_schema(group, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_form_schema(%FormSchema{} = form_schema, attrs) do
    form_schema
    |> FormSchema.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a form_schema.
  ## Examples
      iex> delete_form_schema(form_schema)
      {:ok, %FormSchema{}}
      iex> delete_form_schema(form_schema)
      {:error, %Ecto.Changeset{}}
  """
  def delete_form_schema(%FormSchema{} = form_schema) do
    Repo.delete(form_schema)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking form_schema changes.
  ## Examples
      iex> change_form_schema(form_schema)
      %Ecto.Changeset{data: %FormSchema{}}
  """
  def change_form_schema(%FormSchema{} = form_schema, attrs \\ %{}) do
    FormSchema.changeset(form_schema, attrs)
  end
end
