defmodule Dbservice.Services.GurukulConfigServiceTest do
  use Dbservice.DataCase

  alias Dbservice.Repo
  alias Dbservice.Services.GurukulConfigService
  alias Dbservice.Groups.AuthGroup
  alias Dbservice.Programs.Program
  alias Dbservice.Batches.Batch
  alias Dbservice.EnrollmentRecords.EnrollmentRecord

  import Dbservice.UsersFixtures
  import Dbservice.ProductsFixtures

  defp default_group_fixture(config) do
    Repo.insert!(%AuthGroup{name: "defaultgroup", input_schema: %{"gurukul_config" => config}})
  end

  defp program_fixture(config) do
    product = product_fixture()

    Repo.insert!(%Program{
      name: "Program #{System.unique_integer([:positive])}",
      product_id: product.id,
      config: config
    })
  end

  defp batch_fixture(program, metadata) do
    Repo.insert!(%Batch{
      name: "Batch #{System.unique_integer([:positive])}",
      program_id: program && program.id,
      metadata: metadata
    })
  end

  defp enroll(user, group_type, group_id, start_date) do
    Repo.insert!(%EnrollmentRecord{
      user_id: user.id,
      group_type: group_type,
      group_id: group_id,
      is_current: true,
      academic_year: "2026-2027",
      start_date: start_date
    })
  end

  describe "resolve_for_program/1" do
    test "merges program config over the defaultgroup base" do
      default_group_fixture(%{"showTests" => false, "testsSectionTitle" => "Live Test"})
      program = program_fixture(%{"testsSectionTitle" => "JEE Live Test"})

      {config, resolved_from} = GurukulConfigService.resolve_for_program(program.id)

      assert config == %{"showTests" => false, "testsSectionTitle" => "JEE Live Test"}
      assert resolved_from.source == "program"
      assert resolved_from.program_id == program.id
    end

    test "falls back to defaultgroup when the program does not exist" do
      default_group_fixture(%{"showTests" => true})

      {config, resolved_from} = GurukulConfigService.resolve_for_program(-1)

      assert config == %{"showTests" => true}
      assert resolved_from.source == "defaultgroup"
    end
  end

  describe "resolve_for_batch/1" do
    test "merges batch over program over defaultgroup (batch wins)" do
      default_group_fixture(%{
        "showTests" => true,
        "homeTabLabel" => "Home",
        "showHomeTab" => true
      })

      program = program_fixture(%{"testsSectionTitle" => "NVS Live Test", "showHomeTab" => false})
      batch = batch_fixture(program, %{"gurukul_config" => %{"testsSectionTitle" => "CA Test"}})

      {config, resolved_from} = GurukulConfigService.resolve_for_batch(batch.id)

      assert config == %{
               "showTests" => true,
               "homeTabLabel" => "Home",
               "showHomeTab" => false,
               "testsSectionTitle" => "CA Test"
             }

      assert resolved_from.source == "batch"
      assert resolved_from.batch_id == batch.id
      assert resolved_from.program_id == program.id
    end

    test "works when the batch has no gurukul_config (program + default only)" do
      default_group_fixture(%{"showTests" => true})
      program = program_fixture(%{"testsSectionTitle" => "NVS Live Test"})
      batch = batch_fixture(program, %{})

      {config, _resolved_from} = GurukulConfigService.resolve_for_batch(batch.id)

      assert config == %{"showTests" => true, "testsSectionTitle" => "NVS Live Test"}
    end
  end

  describe "resolve_for_user/1" do
    test "uses the oldest current batch when a user is in multiple batches" do
      default_group_fixture(%{"showTests" => true})
      old_program = program_fixture(%{"testsSectionTitle" => "Old"})
      new_program = program_fixture(%{"testsSectionTitle" => "New"})
      old_batch = batch_fixture(old_program, %{"gurukul_config" => %{"homeTabLabel" => "Older"}})
      new_batch = batch_fixture(new_program, %{"gurukul_config" => %{"homeTabLabel" => "Newer"}})

      user = user_fixture()
      enroll(user, "batch", new_batch.id, ~D[2026-06-01])
      enroll(user, "batch", old_batch.id, ~D[2025-06-01])

      {config, resolved_from} = GurukulConfigService.resolve_for_user(user.id)

      assert resolved_from.source == "batch"
      assert resolved_from.batch_id == old_batch.id
      assert config["testsSectionTitle"] == "Old"
      assert config["homeTabLabel"] == "Older"
    end

    test "falls back to oldest current program when the user has no batch" do
      default_group_fixture(%{"showTests" => true})
      program = program_fixture(%{"testsSectionTitle" => "Program Title"})

      user = user_fixture()
      enroll(user, "program", program.id, ~D[2026-06-01])

      {config, resolved_from} = GurukulConfigService.resolve_for_user(user.id)

      assert resolved_from.source == "program"
      assert resolved_from.program_id == program.id
      assert config["testsSectionTitle"] == "Program Title"
    end

    test "returns the defaultgroup config when the user has no enrollments" do
      default_group_fixture(%{"showTests" => true, "homeTabLabel" => "Home"})
      user = user_fixture()

      {config, resolved_from} = GurukulConfigService.resolve_for_user(user.id)

      assert config == %{"showTests" => true, "homeTabLabel" => "Home"}
      assert resolved_from.source == "defaultgroup"
    end

    test "returns an empty config when there is no defaultgroup and no enrollments" do
      user = user_fixture()

      assert {%{}, %{source: "defaultgroup"}} = GurukulConfigService.resolve_for_user(user.id)
    end
  end
end
