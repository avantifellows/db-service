defmodule DbserviceWeb.ResourceView do
  use DbserviceWeb, :view
  alias DbserviceWeb.ResourceView
  alias Dbservice.Resources.ResourceTopic
  alias Dbservice.Resources.ResourceChapter
  alias Dbservice.Repo
  import Ecto.Query

  def render("index.json", %{resource: resource}) do
    render_many(resource, ResourceView, "resource.json")
  end

  def render("show.json", %{resource: resource}) do
    render_one(resource, ResourceView, "resource.json")
  end

  def render("resource.json", %{resource: resource}) do
    topic_id =
      Repo.one(
        from rt in ResourceTopic,
          where: rt.resource_id == ^resource.id,
          select: rt.topic_id,
          limit: 1
      )

    chapter_id =
      Repo.one(
        from rt in ResourceChapter,
          where: rt.resource_id == ^resource.id,
          select: rt.chapter_id,
          limit: 1
      )

    base_map = %{
      id: resource.id,
      name: resource.name,
      type: resource.type,
      type_params: resource.type_params,
      subtype: resource.subtype,
      source: resource.source,
      code: resource.code,
      purpose_ids: resource.purpose_ids,
      tag_ids: resource.tag_ids,
      skill_ids: resource.skill_ids,
      learning_objective_ids: resource.learning_objective_ids,
      teacher_id: resource.teacher_id,
      topic_id: topic_id,
      chapter_id: chapter_id
    }

    if Map.has_key?(resource, :meta_data) do
      Map.put(base_map, :meta_data, resource.meta_data)
    else
      base_map
    end
  end

  def render("problems.json", %{problems: problems}) do
    Enum.map(problems, fn problem -> render("problem.json", problem: problem) end)
  end

  def render("problem.json", %{problem: problem}) do
    # First get the base resource
    resource = problem.resource
    resource_topic = problem.resource_topic
    resource_curriculum = problem.resource_curriculum
    problem_lang = problem.problem_lang

    # Get the base resource data using your existing pattern
    topic_id = resource_topic.topic_id

    chapter_id =
      Repo.one(
        from rt in ResourceChapter,
          where: rt.resource_id == ^resource.id,
          select: rt.chapter_id,
          limit: 1
      )

    # Build the base resource representation
    base_map = %{
      id: resource.id,
      name: resource.name,
      type: resource.type,
      type_params: resource.type_params,
      subtype: resource.subtype,
      source: resource.source,
      code: resource.code,
      purpose_ids: resource.purpose_ids,
      tag_ids: resource.tag_ids,
      skill_ids: resource.skill_ids,
      learning_objective_ids: resource.learning_objective_ids,
      teacher_id: resource.teacher_id,
      topic_id: topic_id,
      chapter_id: chapter_id
    }

    # Add curriculum data
    resource_with_curriculum =
      Map.merge(base_map, %{
        curriculum_id: resource_curriculum.curriculum_id,
        difficulty_level: resource_curriculum.difficulty_level,
        grade_id: resource_curriculum.grade_id,
        subject_id: resource_curriculum.subject_id
      })

    # Add problem language data
    Map.merge(resource_with_curriculum, %{
      meta_data: problem_lang.meta_data,
      lang_id: problem_lang.lang_id
    })
  end

  def render("problem_lang.json", %{
        resource: resource,
        meta_data: meta_data,
        lang_code: lang_code
      }) do
    base = render_one(resource, __MODULE__, "resource.json", as: :resource)

    base
    |> Map.put(:meta_data, meta_data)
    |> Map.put(:lang_code, lang_code)
  end
end
