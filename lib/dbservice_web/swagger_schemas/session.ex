defmodule DbserviceWeb.SwaggerSchema.Session do
  @moduledoc false

  use PhoenixSwagger

  def session do
    %{
      Session:
        swagger_schema do
          title("Session")
          description("A session in the application")

          properties do
            name(:string, "First name")
            platform(:string, "Platform where session being hosted")
            platform_link(:string, "Link for the platform")
            portal_link(:text, "Link generated by the portal")
            start_time(:timestamp, "Session start time")
            end_time(:timestamp, "Session finish time")
            repeat_schedule(:json, "Repeat type and repeat till date for session")
            meta_data(:map, "Additional meta data for the session")
            owner_id(:integer, "User ID for the session owner")
            created_by_id(:integer, "User ID for the session creator")
            is_active(:boolean, "Tells whether session is active or not")
            session_id(:string, "Id for the session")
            form_schema_id(:string, "Id for the form schema")
            type(:string, "Type of session")
            auth_type(:string, "Authentication methods used for session")
            activate_signup(:boolean, "Is sign up allowed for this session")
            id_generation(:boolean, "Is ID being generated for this session")
            redirection(:boolean, "Is the session redirecting to some other platform")
            pop_up_form(:boolean, "Is the session showing a pop up form")
            number_of_fields_in_pop_form(:string, "Number of fields in the pop form")
          end

          example(%{
            name: "Kendriya Vidyalaya - Weekly Maths class 7",
            platform: "meet",
            platform_link: "https://meet.google.com/asl-skas-qwe",
            portal_link: "https://links.af.org/kv-wmc7",
            start_time: "2022-02-02T11:00:00Z",
            end_time: "2022-02-02T11:30:00Z",
            repeat_schedule: %{
              "repeat-type" => "weekly",
              "repeat-till-date" => "2022-12-31 11:59:59"
            },
            meta_data: %{
              "substitute-teacher-name" => "Ms. Poonam"
            },
            owner_id: 2,
            created_by_id: 1,
            is_active: true,
            session_id: "c714-e1d4-5a42-0f9f-36b3",
            form_schema_id: 1
          })
        end
    }
  end

  def sessions do
    %{
      Sessions:
        swagger_schema do
          title("Sessions")
          description("All the sessions")
          type(:array)
          items(Schema.ref(:Session))
        end
    }
  end
end
