defmodule DbserviceWeb.ErrorJsonTest do
  use DbserviceWeb.ConnCase, async: true

  test "renders 404.json with reason containing message" do
    reason = %{message: "Custom not found message"}

    assert DbserviceWeb.ErrorJSON.render("404.json", reason: reason) ==
             %{errors: %{detail: "Not Found", message: "Custom not found message"}}
  end

  test "renders 500.json with reason containing message" do
    reason = %{message: "Database connection failed"}

    assert DbserviceWeb.ErrorJSON.render("500.json", reason: reason) ==
             %{errors: %{detail: "Internal Server Error", message: "Database connection failed"}}
  end

  test "renders 400.json with reason containing message" do
    reason = %{message: "Invalid input format"}

    assert DbserviceWeb.ErrorJSON.render("400.json", reason: reason) ==
             %{errors: %{detail: "Bad Request", message: "Invalid input format"}}
  end

  test "renders unknown error with reason containing message" do
    reason = %{message: "Custom unknown error message"}

    assert DbserviceWeb.ErrorJSON.render("403.json", reason: reason) ==
             %{errors: %{detail: "Unknown error", message: "Custom unknown error message"}}
  end

  test "renders error with reason containing special characters" do
    reason = %{message: "Error with\nnewlines and \"quotes\""}

    assert DbserviceWeb.ErrorJSON.render("500.json", reason: reason) ==
             %{
               errors: %{
                 detail: "Internal Server Error",
                 message: "Error with newlines and quotes"
               }
             }
  end

  test "template_not_found returns correct structure" do
    assert DbserviceWeb.ErrorJSON.template_not_found("422.json", []) ==
             %{errors: %{detail: "Unprocessable Content"}}
  end

  test "a malformed body outside the Visit Concern API gets the standard 400 shape",
       %{conn: conn} do
    assert {400, _headers, body} =
             assert_error_sent(400, fn ->
               conn
               |> put_req_header("content-type", "application/json")
               |> put("/api/school/1", ~s({"name": "trunc))
             end)

    assert Jason.decode!(body) == %{
             "errors" => %{"detail" => "Bad Request", "message" => "malformed request body"}
           }
  end
end
