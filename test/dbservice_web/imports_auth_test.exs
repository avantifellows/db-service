defmodule DbserviceWeb.ImportsAuthTest do
  use DbserviceWeb.ConnCase

  import Phoenix.LiveViewTest

  @email "importer@avantifellows.org"

  defp sign_in(conn) do
    Plug.Test.init_test_session(conn, %{
      "current_user_email" => @email,
      "current_user_name" => "Test Importer"
    })
  end

  describe "signed out" do
    test "the imports list redirects to the sign-in page", %{conn: conn} do
      conn = get(conn, ~p"/imports")
      assert redirected_to(conn) == ~p"/signin"
    end

    test "the new import page redirects to the sign-in page", %{conn: conn} do
      conn = get(conn, ~p"/imports/new")
      assert redirected_to(conn) == ~p"/signin"
    end

    test "an import detail page redirects to the sign-in page", %{conn: conn} do
      conn = get(conn, ~p"/imports/1")
      assert redirected_to(conn) == ~p"/signin"
    end

    test "CSV template downloads redirect to the sign-in page", %{conn: conn} do
      conn = get(conn, ~p"/templates/student/download")
      assert redirected_to(conn) == ~p"/signin"
    end

    test "the sign-in page itself is reachable", %{conn: conn} do
      conn = get(conn, ~p"/signin")
      response = html_response(conn, 200)

      assert response =~ "Sign in with Google"
      assert response =~ "avantifellows.org"
    end

    test "the requested page is remembered for after sign-in", %{conn: conn} do
      conn = get(conn, ~p"/imports/new")
      assert Plug.Conn.get_session(conn, "user_return_to") == "/imports/new"
    end
  end

  describe "signed in" do
    test "the imports list renders and names the signed-in user", %{conn: conn} do
      {:ok, _view, html} = conn |> sign_in() |> live(~p"/imports")

      assert html =~ @email
      assert html =~ "Sign out"
    end

    test "the new import page says who the import will be recorded against", %{conn: conn} do
      {:ok, _view, html} = conn |> sign_in() |> live(~p"/imports/new")

      assert html =~ "recorded against"
      assert html =~ @email
    end
  end

  describe "logging out" do
    test "clears the session and returns to the sign-in page", %{conn: conn} do
      conn = conn |> sign_in() |> get(~p"/auth/logout")

      assert redirected_to(conn) == ~p"/signin"
      refute Plug.Conn.get_session(conn, "current_user_email")
    end
  end
end
