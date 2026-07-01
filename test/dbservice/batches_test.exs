defmodule Dbservice.BatchesTest do
  use Dbservice.DataCase

  alias Dbservice.Batches
  alias Dbservice.Batches.Batch

  import Dbservice.BatchesFixtures

  describe "correct_batch_id/2" do
    test "renames the batch_id in place, keeping the same batch row" do
      batch = batch_fixture(%{batch_id: "EnableStudenst_TP_2027_engg_A001"})

      assert {:ok, %Batch{} = updated} =
               Batches.correct_batch_id(
                 "EnableStudenst_TP_2027_engg_A001",
                 "EnableStudents_TP_2027_engg_A001"
               )

      assert updated.id == batch.id
      assert updated.batch_id == "EnableStudents_TP_2027_engg_A001"
      assert is_nil(Batches.get_batch_by_batch_id("EnableStudenst_TP_2027_engg_A001"))
    end

    test "trims surrounding whitespace on both ids" do
      batch = batch_fixture(%{batch_id: "OLD_BATCH"})

      assert {:ok, %Batch{} = updated} =
               Batches.correct_batch_id("  OLD_BATCH  ", "  NEW_BATCH  ")

      assert updated.id == batch.id
      assert updated.batch_id == "NEW_BATCH"
    end

    test "errors when no batch has the old batch_id" do
      assert {:error, message} = Batches.correct_batch_id("DOES_NOT_EXIST", "NEW_BATCH")
      assert message =~ "No batch found"
    end

    test "errors when the new batch_id already belongs to another batch" do
      _existing = batch_fixture(%{batch_id: "CORRECT_BATCH"})
      batch_fixture(%{batch_id: "WRONG_BATCH"})

      assert {:error, message} = Batches.correct_batch_id("WRONG_BATCH", "CORRECT_BATCH")
      assert message =~ "already exists for another batch"

      # The wrong batch is left untouched.
      assert Batches.get_batch_by_batch_id("WRONG_BATCH")
    end

    test "errors when an id is blank or missing" do
      batch_fixture(%{batch_id: "SOME_BATCH"})

      assert {:error, "old_batch_id is required"} = Batches.correct_batch_id("", "NEW_BATCH")
      assert {:error, "old_batch_id is required"} = Batches.correct_batch_id(nil, "NEW_BATCH")
      assert {:error, "new_batch_id is required"} = Batches.correct_batch_id("SOME_BATCH", "  ")
    end
  end

  describe "correct_batch_id/2 session metadata" do
    import Dbservice.SessionsFixtures

    alias Dbservice.Repo
    alias Dbservice.Sessions.Session

    defp session_batch_id(session_id) do
      Repo.get!(Session, session_id).meta_data["batch_id"]
    end

    test "rewrites the renamed batch_id inside session meta_data batch_id lists" do
      batch_fixture(%{batch_id: "WRONG_A"})

      single = session_fixture(%{meta_data: %{"batch_id" => "WRONG_A"}})
      multi = session_fixture(%{meta_data: %{"batch_id" => "OTHER,WRONG_A,MORE"}})
      untouched = session_fixture(%{meta_data: %{"batch_id" => "SOMETHING_ELSE"}})

      assert {:ok, _batch} = Batches.correct_batch_id("WRONG_A", "RIGHT_A")

      # Standalone and mid-list occurrences are replaced; order and siblings preserved.
      assert session_batch_id(single.id) == "RIGHT_A"
      assert session_batch_id(multi.id) == "OTHER,RIGHT_A,MORE"
      # A substring-only match (SOMETHING_ELSE contains no exact WRONG_A token) is left alone.
      assert session_batch_id(untouched.id) == "SOMETHING_ELSE"
    end
  end
end
