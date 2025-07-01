defmodule DbserviceWeb.ResourceView do
  use DbserviceWeb, :view
  alias DbserviceWeb.ResourceView
  alias DbserviceWeb.ConceptView
  alias Dbservice.Resources.ResourceTopic
  alias Dbservice.Resources.ResourceChapter
  alias Dbservice.Concepts
  alias Dbservice.ResourceConcepts
  alias Dbservice.Repo
  import Ecto.Query

  def render("index.json", %{resource: resources}) do
    Enum.map(resources, fn resource ->
      cond do
        Map.has_key?(resource, :type) and resource.type == "problem" ->
          render("problem.json",
            problem: %{
              resource: resource,
              resource_topic: %{},
              resource_curriculum: %{},
              problem_lang: %{}
            }
          )

        true ->
          render_one(resource, ResourceView, "resource.json")
      end
    end)
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

    # Add curriculum data if it exists
    base_map =
      if Map.has_key?(resource, :difficulty_level) do
        Map.merge(base_map, %{
          difficulty_level: resource.difficulty_level,
          curriculum_id: resource.curriculum_id,
          grade_id: resource.grade_id,
          subject_id: resource.subject_id
        })
      else
        base_map
      end

    # Add meta_data if it exists
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
    resource_topic = Map.get(problem, :resource_topic, %{})
    resource_curriculum = Map.get(problem, :resource_curriculum, %{})
    problem_lang = Map.get(problem, :problem_lang, %{})

    # Get the base resource data using your existing pattern
    topic_id = Map.get(resource_topic, :topic_id, nil)

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
        curriculum_id: Map.get(resource_curriculum, :curriculum_id, nil),
        difficulty_level: Map.get(resource_curriculum, :difficulty_level, nil),
        grade_id: Map.get(resource_curriculum, :grade_id, nil),
        subject_id: Map.get(resource_curriculum, :subject_id, nil)
      })

    # Add problem language data
    problem_map =
      Map.merge(resource_with_curriculum, %{
        meta_data: Map.get(problem_lang, :meta_data, nil),
        lang_id: Map.get(problem_lang, :lang_id, nil)
      })

    # Fetch concept information
    resource_concepts = ResourceConcepts.get_resource_concepts_by_resource_id(resource.id)

    concepts =
      Enum.map(resource_concepts, fn rc ->
        concept = Concepts.get_concept!(rc.concept_id)
        ConceptView.render("concept.json", %{concept: concept})
      end)

    Map.put(problem_map, :concepts, concepts)
  end

  def render("problem_lang.json", %{
        resource: resource,
        meta_data: meta_data,
        lang_code: lang_code,
        resource_curriculum: rc
      }) do
    base = render_one(resource, __MODULE__, "resource.json", as: :resource)

    # Fetch concept information
    resource_concepts = ResourceConcepts.get_resource_concepts_by_resource_id(resource.id)

    concepts =
      Enum.map(resource_concepts, fn rc ->
        concept = Concepts.get_concept!(rc.concept_id)
        ConceptView.render("concept.json", %{concept: concept})
      end)

    base
    |> Map.put(:meta_data, meta_data)
    |> Map.put(:lang_code, lang_code)
    |> Map.merge(%{
      curriculum_id: rc.curriculum_id,
      grade_id: rc.grade_id,
      subject_id: rc.subject_id,
      difficulty_level: rc.difficulty_level,
      concepts: concepts
    })
  end
end
