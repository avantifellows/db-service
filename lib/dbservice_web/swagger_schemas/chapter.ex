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
            name(:string, "Chapter name")
            code(:string, "Chapter Code")
            grade_ids({:array, :integer}, "Array of grade ids associated with the chapter")
            subject_id(:integer, "Subject id associated with the chapter")
            tag_id(:integer, "Tag id associated with the chapter")
            curriculum_id(:integer, "Curriculum id associated with the chapter")
          end

          example(%{
            name: "हमारे आस-पास के पदार्थ | Matter in Our Surroundings",
            code: "9C01",
            grade_ids: [1, 2, 3],
            subject_id: 1,
            tag_id: 4,
            curriculum_id: 1
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
