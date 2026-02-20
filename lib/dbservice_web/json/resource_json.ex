defmodule DbserviceWeb.ResourceJSON do
  alias DbserviceWeb.ConceptJSON
  alias Dbservice.Resources.ResourceTopic
  alias Dbservice.Resources.ResourceChapter
  alias Dbservice.Concepts
  alias Dbservice.ResourceConcepts
  alias Dbservice.ResourceCurriculums
  alias Dbservice.Repo
  import Ecto.Query

  def index(%{resource: resources}) do
    Enum.map(resources, fn resource ->
      # If resource is a map with :resource key, it's the new structure
      if Map.has_key?(resource, :resource) do
        render_problem(resource)
      else
        render(resource)
      end
    end)
  end

  def show(%{resource: resource}) do
    render(resource)
  end

  defp render(resource) do
    topic_id =
      Repo.one(
        from rt in ResourceTopic,
          where: rt.resource_id == ^resource.id,
          select: rt.topic_id,
          limit: 1
      )

    exam_details =
      Dbservice.Exams.get_exams_by_ids(resource.exam_ids)
      |> Enum.map(&DbserviceWeb.ExamJSON.render/1)

    chapter_id =
      Repo.one(
        from rt in ResourceChapter,
          where: rt.resource_id == ^resource.id,
          select: rt.chapter_id,
          limit: 1
      )

    # Fetch all resource_curriculum records for this resource
    resource_curriculums =
      ResourceCurriculums.list_resource_curriculums_by_resource_id(resource.id)

    curriculum_grades =
      Enum.map(resource_curriculums, fn rc ->
        %{
          curriculum_id: rc.curriculum_id,
          grade_id: rc.grade_id
        }
      end)

    base_map = %{
      id: resource.id,
      name: resource.name,
      type: resource.type,
      subtype: resource.subtype,
      code: resource.code,
      type_params: resource.type_params,
      source: resource.source,
      purpose_ids: resource.purpose_ids,
      tag_ids: resource.tag_ids,
      skill_ids: resource.skill_ids,
      learning_objective_ids: resource.learning_objective_ids,
      teacher_id: resource.teacher_id,
      topic_id: topic_id,
      chapter_id: chapter_id,
      cms_status_id: resource.cms_status_id,
      exam_ids: resource.exam_ids,
      exam_details: exam_details,
      curriculum_grades: curriculum_grades
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

  def problems(%{problems: problems}) do
    Enum.map(problems, fn problem -> render_problem(problem) end)
  end

  defp render_problem(problem) do
    # First get the base resource
    resource = problem.resource
    resource_topic = Map.get(problem, :resource_topic, %{})
    resource_curriculums = Map.get(problem, :resource_curriculums, [])
    requested_curriculum_id = Map.get(problem, :requested_curriculum_id)
    problem_lang = Map.get(problem, :problem_lang, %{})

    # Get the base resource data using your existing pattern
    topic_id = Map.get(resource_topic, :topic_id, nil)

    # Get chapter information from preloaded data or fallback to query
    chapter_data =
      if Ecto.assoc_loaded?(resource.chapter) && not Enum.empty?(resource.chapter) do
        chapter = List.first(resource.chapter)

        %{
          chapter_id: chapter.id,
          chapter_code: chapter.code,
          chapter_name: chapter.name
        }
      else
        %{chapter_id: nil, chapter_code: nil, chapter_name: nil}
      end

    # Build curriculum_grades from resource_curriculums
    curriculum_grades =
      Enum.map(resource_curriculums, fn rc ->
        %{
          curriculum_id: rc.curriculum_id,
          grade_id: rc.grade_id
        }
      end)

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
      chapter_id: chapter_data.chapter_id,
      chapter_code: chapter_data.chapter_code,
      chapter_name: chapter_data.chapter_name,
      cms_status_id: resource.cms_status_id,
      curriculum_grades: curriculum_grades
    }

    # Find the curriculum mapping for the requested curriculum_id, or fallback to the first one
    curriculum =
      Enum.find(resource_curriculums, fn rc -> rc.curriculum_id == requested_curriculum_id end) ||
        List.first(resource_curriculums) || %{}

    resource_with_curriculum =
      Map.merge(base_map, %{
        curriculum_id: Map.get(curriculum, :curriculum_id, nil),
        difficulty_level: Map.get(curriculum, :difficulty_level, nil),
        grade_id: Map.get(curriculum, :grade_id, nil),
        subject_id: Map.get(curriculum, :subject_id, nil)
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
        ConceptJSON.render(concept)
      end)

    Map.put(problem_map, :concepts, concepts)
  end

  def problem_lang(%{
        resource: resource,
        meta_data: meta_data,
        lang_code: lang_code,
        resource_curriculum: rc
      }) do
    base = render(resource)

    # Fetch concept information
    resource_concepts = ResourceConcepts.get_resource_concepts_by_resource_id(resource.id)

    concepts =
      Enum.map(resource_concepts, fn rc ->
        concept = Concepts.get_concept!(rc.concept_id)
        ConceptJSON.render(concept)
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
