defmodule DbserviceWeb.SwaggerSchema.Resource do
  @moduledoc false

  use PhoenixSwagger

  def resource do
    %{
      Resource:
        swagger_schema do
          title("Resource")
          description("A resource in the application")

          properties do
            name(
              Schema.array(:object),
              "Multilingual names for the resource, each with a language code and value",
              example: [
                %{lang: "en", value: "1. 9C01 Introduction - Matter in our Surroundings"},
                %{lang: "hi", value: "1. 9C01 परिचय - हमारे आस पास के पदार्थ"}
              ]
            )

            type(:string, "Resource type")
            subtype(:string, "Resource subtype")
            code(:string, "Resource code")
            type_params(:map, "Parameters of the resource type")
            subtype(:string, "Sub-type of a resource")
            source(:string, "Source of a resource")
            code(:string, "Code of a resource")
            purpose_ids(:array, "Purpose ids associated with the resource")
            learning_objective_ids(:array, "Learning objective ids associated with the resource")
            tag_ids(:array, "Tag ids associated with the resource")
            skill_ids(:array, "Skill ids associated with the resource")
            teacher_id(:integer, "Teacher id associated with the resource")
            exam_ids(:array, "Exam ids associated with the resource")
          end

          example(%{
            name: [
              %{lang: "en", value: "1. 9C01 Introduction - Matter in our Surroundings"},
              %{lang: "hi", value: "1. 9C01 परिचय - हमारे आस पास के पदार्थ"}
            ],
            type: "video",
            subtype: "lecture",
            code: "RSC-001",
            type_params: %{"src_link" => "https://youtube.com/test_video"},
            source: "youtube",
            purpose_ids: [1, 2, 3],
            learning_objective_ids: [4, 5, 6],
            tag_ids: [5, 7, 9],
            skill_ids: [1, 3, 7],
            teacher_id: 1,
            exam_ids: [1, 2, 3]
          })
        end
    }
  end

  def resources do
    %{
      Resources:
        swagger_schema do
          title("Resources")
          description("All resources in the application")
          type(:array)
          items(Schema.ref(:Resource))
        end
    }
  end

  def resource_curriculum do
    %{
      ResourceCurriculum:
        swagger_schema do
          title("ResourceCurriculum")
          description("A resource-curriculum in the application")

          properties do
            resource_id(:integer, "Resource id associated with the resource")
            curriculum_id(:integer, "Curriculum id associated with the resource")
            difficulty_level(:string, "Difficulty level of a resource")
            grade_id(:integer, "Grade id associated with the resource")
            subject_id(:integer, "Subject id associated with the resource")
          end

          example(%{
            resource_id: 1,
            curriculum_id: 1,
            difficulty_level: "medium"
          })
        end
    }
  end

  def resource_curriculums do
    %{
      ResourceCurriculums:
        swagger_schema do
          title("ResourceCurriculums")
          description("All resources-curriculums in the application")
          type(:array)
          items(Schema.ref(:ResourceCurriculum))
        end
    }
  end

  def resource_chapter do
    %{
      ResourceChapter:
        swagger_schema do
          title("ResourceChapter")
          description("A resource-chapter in the application")

          properties do
            resource_id(:integer, "Resource id associated with the resource")
            chapter_id(:integer, "Chapter id associated with the resource")
          end

          example(%{
            resource_id: 1,
            chapter_id: 1
          })
        end
    }
  end

  def resource_chapters do
    %{
      ResourceChapters:
        swagger_schema do
          title("ResourceChapters")
          description("All resources-chapters in the application")
          type(:array)
          items(Schema.ref(:ResourceCurriculum))
        end
    }
  end

  def resource_topic do
    %{
      ResourceTopic:
        swagger_schema do
          title("ResourceTopic")
          description("A resource-topic in the application")

          properties do
            resource_id(:integer, "Resource id associated with the resource")
            topic_id(:integer, "Topic id associated with the resource")
          end

          example(%{
            resource_id: 1,
            topic_id: 1
          })
        end
    }
  end

  def resource_topics do
    %{
      ResourceTopics:
        swagger_schema do
          title("ResourceTopics")
          description("All resources-topics in the application")
          type(:array)
          items(Schema.ref(:ResourceTopic))
        end
    }
  end

  def resource_concept do
    %{
      ResourceConcept:
        swagger_schema do
          title("ResourceConcept")
          description("A resource-concept in the application")

          properties do
            resource_id(:integer, "Resource id associated with the resource")
            concept_id(:integer, "Concept id associated with the resource")
          end

          example(%{
            resource_id: 1,
            concept_id: 1
          })
        end
    }
  end

  def resource_concepts do
    %{
      ResourceConcepts:
        swagger_schema do
          title("ResourceConcepts")
          description("All resources-topics in the application")
          type(:array)
          items(Schema.ref(:ResourceConcept))
        end
    }
  end

  def problem_language do
    %{
      ProblemLanguage:
        swagger_schema do
          title("ProblemLanguage")
          description("A problem-language in the application")

          properties do
            res_id(:integer, "Resource id associated with the resource")
            lang_id(:integer, "Language id associated with the resource")
            meta_data(:map, "Additional meta data for the session")
          end

          example(%{
            res_id: 1,
            lang_id: 1,
            meta_data: %{
              "difficulty" => "medium"
            }
          })
        end
    }
  end

  def problem_languages do
    %{
      ProblemLanguages:
        swagger_schema do
          title("ProblemLanguages")
          description("All problem-languages in the application")
          type(:array)
          items(Schema.ref(:ProblemLanguage))
        end
    }
  end

  def problem_resource do
    %{
      ProblemResource:
        swagger_schema do
          title("ProblemResource")
          description("A problem-resource in the application")

          properties do
            name(
              Schema.array(:object),
              "Multilingual names for the resource, each with a language code and value",
              example: [
                %{lang: "en", value: "1. 9C01 Introduction - Matter in our Surroundings"},
                %{lang: "hi", value: "1. 9C01 परिचय - हमारे आस पास के पदार्थ"}
              ]
            )

            type(:string, "Resource type")
            type_params(:map, "Parameters of the resource type")
            subtype(:string, "Sub-type of a resource")
            source(:string, "Source of a resource")
            code(:string, "Code of a resource")
            purpose_ids(:array, "Purpose ids associated with the resource")
            learning_objective_ids(:array, "Learning objective ids associated with the resource")
            tag_ids(:array, "Tag ids associated with the resource")
            skill_ids(:array, "Skill ids associated with the resource")
            teacher_id(:integer, "Teacher id associated with the resource")
            meta_data(:map, "Additional meta data for the session")
            curriculum_id(:integer, "Curriculum id associated with the resource")
            grade_id(:integer, "Grade id associated with the resource")
            subject_id(:integer, "Subject id associated with the resource")
            concepts(:array, "Concepts associated with the resource")
          end

          example(%{
            name: [
              %{lang: "en", value: "Coulomb's Law"},
              %{lang: "hi", value: "कूलॉम्ब का नियम"}
            ],
            type: "problem",
            type_params: %{
              "marks" => 60,
              "duration" => "60",
              "subjects" => [
                %{
                  "marks" => 12,
                  "sections" => [
                    %{
                      "name" => "section 1",
                      "marks" => 6,
                      "optional" => %{},
                      "compulsory" => %{
                        "problems" => [
                          %{"id" => 4, "neg_marks" => [-1], "pos_marks" => [1, 2]},
                          %{"id" => 5, "neg_marks" => [-1], "pos_marks" => [1, 2]}
                        ]
                      }
                    }
                  ],
                  "subject_id" => 1
                }
              ],
              "neg_marks" => [-0.5, -1],
              "pos_marks" => [0.5, 1, 1.5, 2],
              "grade_name" => 12,
              "curriculum_name" => "TNJEE"
            },
            subtype: "mcq",
            source: "internal",
            code: "PROB_COULOMB_001",
            purpose_ids: [1, 2, 3],
            learning_objective_ids: [4, 5, 6],
            tag_ids: [5, 7, 9],
            skill_ids: [1, 3, 7],
            teacher_id: 1,
            meta_data: %{difficulty: "medium"},
            curriculum_id: 1,
            grade_id: 12,
            subject_id: 2,
            concepts: [
              %{
                name: [
                  %{lang: "en", value: "Coulomb's Law"},
                  %{lang: "hi", value: "कूलॉम्ब का नियम"}
                ],
                topic_id: 5
              }
            ]
          })
        end
    }
  end
end
