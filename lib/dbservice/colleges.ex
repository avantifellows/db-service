defmodule Dbservice.Colleges do
  @moduledoc false

  import Ecto.Query, warn: false
  alias Dbservice.Repo
  alias Dbservice.Colleges.College

  def list_colleges do
    Repo.all(College)
  end

  def get_college!(id), do: Repo.get!(College, id)

  def get_college_by_college_id(college_id) do
    Repo.get_by(College, college_id: college_id)
  end

  def create_college(attrs \\ %{}) do
    %College{}
    |> College.changeset(attrs)
    |> Repo.insert()
  end

  def update_college(%College{} = college, attrs) do
    college
    |> College.changeset(attrs)
    |> Repo.update()
  end

  def delete_college(%College{} = college) do
    Repo.delete(college)
  end

  def change_college(%College{} = college, attrs \\ %{}) do
    College.changeset(college, attrs)
  end
end
