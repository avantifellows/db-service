defmodule DbserviceWeb.SwaggerSchema.Common do
  @moduledoc false

  use PhoenixSwagger

  def user_ids do
    %{
      UserIds:
        swagger_schema do
          properties do
            user_ids(:array, "List of user ids")
          end

          example(%{
            user_ids: [1, 2]
          })
        end
    }
  end

  def session_ids do
    %{
      SessionIds:
        swagger_schema do
          properties do
            session_ids(:array, "List of session ids")
          end

          example(%{
            session_ids: [1, 2]
          })
        end
    }
  end

  def group_id do
    %{
      GroupIds:
        swagger_schema do
          properties do
            group_id(:array, "List of group ids")
          end

          example(%{
            group_id: [1, 2]
          })
        end
    }
  end
end
