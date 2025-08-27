defmodule DbserviceWeb.SwaggerSchema.TestRule do
  @moduledoc false

  use PhoenixSwagger

  def test_rule do
    %{
      TestRule:
        swagger_schema do
          title("TestRule")
          description("A test rule in application")

          properties do
            exam_id(:integer, "The id of the exam")
            test_type(:string, "Type of the test")
            config(:object, "Config for the test rule")
          end

          example(%{
            exam_id: 1,
            test_type: "mock",
            config: %{"key" => "value"}
          })
        end
    }
  end

  def test_rules do
    %{
      TestRules:
        swagger_schema do
          title("TestRules")
          description("All the test rules")
          type(:array)
          items(Schema.ref(:TestRule))
        end
    }
  end
end
