defmodule DbserviceWeb.SwaggerSchema.Chapter do
  @moduledoc false

  use PhoenixSwagger

  def chapter do
    %{
      Chapter:
        swagger_schema do
          title("Chapter")
          description("A chapter in the application")

          properties do
            name(
              Schema.array(:object),
              "Multilingual chapter names. Each object should contain 'lang_code' and 'chapter' keys",
              example: [
                %{lang_code: "hi", chapter: "हमारे आस-पास के पदार्थ"},
                %{lang_code: "en", chapter: "Matter in Our Surroundings"}
              ]
            )

            code(:string, "Chapter Code")
            grade_id(:integer, "Grade id associated with the chapter")
            subject_id(:integer, "Subject id associated with the chapter")
          end

          example(%{
            name: [
              %{lang_code: "hi", chapter: "हमारे आस-पास के पदार्थ"},
              %{lang_code: "en", chapter: "Matter in Our Surroundings"}
            ],
            code: "9C01",
            grade_id: 1,
            subject_id: 1
          })
        end
    }
  end

  def chapters do
    %{
      Chapters:
        swagger_schema do
          title("Chapters")
          description("All chapters in the application")
          type(:array)
          items(Schema.ref(:Chapter))
        end
    }
  end
end
