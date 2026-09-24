defmodule DbserviceWeb.UserAuthTest do
  use ExUnit.Case, async: true

  alias DbserviceWeb.UserAuth

  describe "authorize_email/1" do
    test "accepts an address on the allowed domain" do
      assert {:ok, "someone@avantifellows.org"} =
               UserAuth.authorize_email("someone@avantifellows.org")
    end

    test "normalises case and surrounding whitespace" do
      assert {:ok, "someone@avantifellows.org"} =
               UserAuth.authorize_email("  SomeOne@AvantiFellows.org ")
    end

    test "rejects an address on another domain" do
      assert {:error, :domain_not_allowed} = UserAuth.authorize_email("someone@gmail.com")
    end

    test "rejects a lookalike domain that merely ends with the allowed one" do
      # Without the leading "@" in the comparison, "notavantifellows.org" would
      # slip through a naive String.ends_with?/2 check.
      assert {:error, :domain_not_allowed} =
               UserAuth.authorize_email("someone@notavantifellows.org")
    end

    test "rejects an address that only contains the domain in its local part" do
      assert {:error, :domain_not_allowed} =
               UserAuth.authorize_email("avantifellows.org@gmail.com")
    end

    test "rejects a missing email" do
      assert {:error, :no_email} = UserAuth.authorize_email(nil)
    end
  end

  describe "bypass_enabled?/0" do
    test "is off by default in the test environment" do
      refute UserAuth.bypass_enabled?()
    end
  end
end
