defmodule DbserviceWeb.ChangesetJSONTest do
  use ExUnit.Case, async: true

  alias DbserviceWeb.ChangesetJSON
  alias Ecto.Changeset

  describe "translate_errors/1" do
    test "translates changeset errors using ErrorHelpers" do
      changeset = %Changeset{
        errors: [
          name: {"can't be blank", []},
          email: {"is invalid", []}
        ]
      }

      result = ChangesetJSON.translate_errors(changeset)

      assert is_map(result)
      assert Map.has_key?(result, :name)
      assert Map.has_key?(result, :email)
      assert is_list(result.name)
      assert is_list(result.email)
    end

    test "handles single field error" do
      changeset = %Changeset{
        errors: [date_of_birth: {"is invalid", [type: :date, validation: :cast]}]
      }

      result = ChangesetJSON.translate_errors(changeset)

      assert is_map(result)
      assert Map.has_key?(result, :date_of_birth)
      assert is_list(result.date_of_birth)
    end

    test "handles empty changeset errors" do
      changeset = %Changeset{errors: []}

      result = ChangesetJSON.translate_errors(changeset)

      assert result == %{}
    end

    test "translates errors with interpolation options" do
      changeset = %Changeset{
        errors: [count: {"must be greater than %{count}", [count: 5]}]
      }

      result = ChangesetJSON.translate_errors(changeset)

      assert is_map(result)
      assert Map.has_key?(result, :count)
      assert is_list(result.count)
    end

    test "handles multiple errors per field" do
      changeset = %Changeset{
        errors: [
          email: {"can't be blank", []},
          email: {"is invalid", []}
        ]
      }

      result = ChangesetJSON.translate_errors(changeset)

      assert is_map(result)
      assert Map.has_key?(result, :email)
      assert is_list(result.email)
      assert length(result.email) == 2
    end

    test "handles complex error options" do
      changeset = %Changeset{
        errors: [
          age: {"must be greater than %{min}", [min: 18, validation: :number]},
          password: {"should be at least %{count} character(s)", [count: 8, validation: :length]}
        ]
      }

      result = ChangesetJSON.translate_errors(changeset)

      assert is_map(result)
      assert Map.has_key?(result, :age)
      assert Map.has_key?(result, :password)
      assert is_list(result.age)
      assert is_list(result.password)
    end
  end

  describe "error/1" do
    test "formats changeset errors as JSON response" do
      changeset = %Changeset{
        errors: [
          name: {"can't be blank", []},
          email: {"is invalid", []}
        ]
      }

      result = ChangesetJSON.error(%{changeset: changeset})

      assert is_map(result)
      assert Map.has_key?(result, :errors)
      assert is_map(result.errors)
      assert Map.has_key?(result.errors, :name)
      assert Map.has_key?(result.errors, :email)
    end

    test "handles single field error in error response" do
      changeset = %Changeset{
        errors: [date_of_birth: {"is invalid", [type: :date, validation: :cast]}]
      }

      result = ChangesetJSON.error(%{changeset: changeset})

      assert is_map(result)
      assert Map.has_key?(result, :errors)
      assert is_map(result.errors)
      assert Map.has_key?(result.errors, :date_of_birth)
    end

    test "handles empty errors in error response" do
      changeset = %Changeset{errors: []}

      result = ChangesetJSON.error(%{changeset: changeset})

      assert is_map(result)
      assert Map.has_key?(result, :errors)
      assert result.errors == %{}
    end

    test "preserves error message structure" do
      changeset = %Changeset{
        errors: [
          name: {"can't be blank", []},
          email: {"has invalid format", [validation: :format]}
        ]
      }

      result = ChangesetJSON.error(%{changeset: changeset})

      assert is_list(result.errors.name)
      assert is_list(result.errors.email)
      assert result.errors.name == ["can't be blank"]
      assert result.errors.email == ["has invalid format"]
    end
  end

  describe "integration with Ecto changesets" do
    test "works with real Ecto changeset" do
      # Create a simple changeset manually for testing
      changeset = %Ecto.Changeset{
        valid?: false,
        errors: [
          name: {"can't be blank", []},
          email: {"has invalid format", [validation: :format]}
        ],
        changes: %{},
        data: %{}
      }

      result = ChangesetJSON.error(%{changeset: changeset})

      assert is_map(result)
      assert Map.has_key?(result, :errors)
      assert is_map(result.errors)
      assert Map.has_key?(result.errors, :name)
      assert Map.has_key?(result.errors, :email)
    end
  end
end
