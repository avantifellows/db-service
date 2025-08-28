defmodule Dbservice.TestRules do
  @moduledoc """
  The TestRules context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.TestRules.TestRule

  @doc """
  Returns the list of test rules.

  ## Examples
      iex> list_test_rules()
      [%TestRule{}, ...]
  """
  def list_test_rules do
    Repo.all(TestRule)
  end

  @doc """
  Gets a single test rule.

  Raises `Ecto.NoResultsError` if the TestRule does not exist.

  ## Examples
      iex> get_test_rule!(123)
      %TestRule{}
      iex> get_test_rule!(456)
      ** (Ecto.NoResultsError)
  """
  def get_test_rule!(id), do: Repo.get!(TestRule, id)

  @doc """
  Creates a test rule.

  ## Examples
      iex> create_test_rule(%{field: value})
      {:ok, %TestRule{}}
      iex> create_test_rule(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_test_rule(attrs \\ %{}) do
    %TestRule{}
    |> TestRule.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a test rule.

  ## Examples
      iex> update_test_rule(test_rule, %{field: new_value})
      {:ok, %TestRule{}}
      iex> update_test_rule(test_rule, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_test_rule(%TestRule{} = test_rule, attrs) do
    test_rule
    |> TestRule.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a test rule.

  ## Examples
      iex> delete_test_rule(test_rule)
      {:ok, %TestRule{}}
      iex> delete_test_rule(test_rule)
      {:error, %Ecto.Changeset{}}
  """
  def delete_test_rule(%TestRule{} = test_rule) do
    Repo.delete(test_rule)
  end
end
