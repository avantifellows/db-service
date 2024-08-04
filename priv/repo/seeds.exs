# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Dbservice.Repo.insert!(%Dbservice.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Dbservice.Programs
alias Dbservice.Repo
alias Dbservice.Users
alias Dbservice.Groups
alias Dbservice.Sessions
alias Dbservice.Schools
alias Dbservice.GroupUsers
alias Dbservice.GroupSessions
alias Dbservice.Batches
alias Dbservice.GroupTypes
alias Dbservice.Batches
alias Dbservice.BatchPrograms
alias Dbservice.FormSchemas
alias Dbservice.Tags
alias Dbservice.Curriculums
alias Dbservice.Grades
alias Dbservice.Subjects
alias Dbservice.Chapters
alias Dbservice.Topics
alias Dbservice.Concepts
alias Dbservice.LearningObjectives
alias Dbservice.Sources
alias Dbservice.Purposes
alias Dbservice.Resources

alias Faker.Person
alias Faker.Internet
alias Faker.Phone
alias Faker.Address

import Ecto.Query

defmodule Seed do
  def random_alphanumeric(length \\ 20) do
    for _ <- 1..length, into: "", do: <<Enum.random('0123456789abcdef')>>
  end

  def create_user() do
    {:ok, user} =
      Users.create_user(%{
        full_name: Person.name(),
        email: Internet.safe_email(),
        phone: Phone.PtPt.number(),
        gender: Enum.random(["male", "female"]),
        city: Address.city(),
        state: Address.state(),
        pincode: Address.postcode(),
        role: "admin",
        whatsapp_phone: Phone.PtPt.number(),
        date_of_birth: Faker.Date.date_of_birth(Enum.random(1..10)),
        country: Enum.random(["India", "Bhutan", "Sri Lanka", "Bangladesh"])
      })

    user
  end

  def create_group() do
    {:ok, group} =
      Groups.create_group(%{
        name: Person.name(),
        input_schema: %{},
        locale: Enum.random(["hi", "en"]),
        locale_data: %{}
      })

    group
  end

  def create_program() do
    group = Seed.create_group()

    {:ok, program} =
      Programs.create_program(%{
        name: Person.name(),
        type: Enum.random(["Competitive", "Non Competitive"]),
        sub_type: Enum.random(["Easy", "Moderate", "High"]),
        mode: Enum.random(["Online", "Offline"]),
        start_date: Faker.DateTime.between(~N[2015-05-19 00:00:00], ~N[2022-10-19 00:00:00]),
        target_outreach: Enum.random(3000..10000),
        product_used: Enum.random(["One", "Less than 5", "More than 5"]),
        donor: Enum.random(["YES", "NO"]),
        state:
          Enum.random([
            "HARYANA",
            "ASSAM",
            "CHATTISGARH",
            "UTTARAKHAND",
            "GUJRAT",
            "DELHI",
            "HIMACHAL PRADESH"
          ]),
        model: Enum.random(["Live Classes"]),
        group_id: group.id
      })

    program
  end

  def create_session() do
    owner = Users.User |> offset(^Enum.random(1..99)) |> limit(1) |> Repo.one()
    creator = Users.User |> offset(^Enum.random(1..99)) |> limit(1) |> Repo.one()

    {:ok, session} =
      Sessions.create_session(%{
        name: "Kendriya Vidyalaya - Weekly Maths class 7",
        platform: Enum.random(["meet", "zoom", "teams"]),
        platform_link:
          Enum.random([
            "https://meet.google.com/asl-skas-qwe",
            "https://meet.google.com/oep-susi-iop"
          ]),
        portal_link:
          Enum.random([
            "https://links.af.org/kv-wmc7",
            "https://links.af.org/io-zmks",
            "https://links.af.org/po-dan"
          ]),
        start_time: Faker.DateTime.between(~N[2022-05-19 00:00:00], ~N[2022-10-20 00:00:00]),
        end_time: Faker.DateTime.between(~N[2022-10-21 00:00:00], ~N[2022-12-22 00:00:00]),
        meta_data: %{},
        owner_id: owner.id,
        created_by_id: creator.id,
        is_active: Enum.random([true, false]),
        purpose: %{},
        repeat_schedule: %{},
        session_id: Seed.random_alphanumeric(),
        platform_id:
          Enum.random([
            "vfr-mndk-ado",
            "nhz-buxn-czq",
            "oaf-hprk-ncw",
            "doo-wzcv-izq"
          ])
      })

    session
  end

  def create_batch() do
    {:ok, batch} =
      Batches.create_batch(%{
        name: Person.name(),
        contact_hours_per_week: Enum.random(20..48)
      })

    batch
  end

  def create_batch_program() do
    batch = Seed.create_batch()
    program = Seed.create_program()

    {:ok, batch_program} =
      BatchPrograms.create_batch_program(%{
        batch_id: batch.id,
        program_id: program.id
      })

    batch_program
  end

  def create_session_occurrence() do
    session = Sessions.Session |> offset(^Enum.random(1..49)) |> limit(1) |> Repo.one()

    {:ok, session_occurrence} =
      Sessions.create_session_occurrence(%{
        session_fk: session.id,
        start_time: session.start_time,
        end_time: session.end_time,
        session_id: Seed.random_alphanumeric()
      })

    session_occurrence
  end

  def create_user_session() do
    session_occurrence =
      Sessions.SessionOccurrence |> offset(^Enum.random(1..99)) |> limit(1) |> Repo.one()

    {:ok, user_session} =
      Sessions.create_user_session(%{
        session_occurrence_id: session_occurrence.id,
        start_time: session_occurrence.start_time,
        end_time: session_occurrence.end_time,
        data: %{},
        is_user_valid: Enum.random([true, false]),
        user_id: Seed.random_alphanumeric()
      })

    user_session
  end

  def create_student() do
    user = Seed.create_user()

    {:ok, student} =
      Users.create_student(%{
        student_id: Seed.random_alphanumeric(),
        father_name: Person.name(),
        father_phone: Phone.PtPt.number(),
        mother_name: Person.name(),
        mother_phone: Phone.PtPt.number(),
        category: Enum.random(["General", "OBC", "SC", "ST"]),
        stream: Enum.random(["Science", "Commerce", "Arts"]),
        user_id: user.id,
        physically_handicapped: Enum.random([true, false]),
        father_profession:
          Enum.random(["Self-employed", "Unemployed", "Private employee", "Government employee"]),
        father_education_level: Enum.random(["UG", "PG", "NA"]),
        mother_profession:
          Enum.random([
            "Housewife",
            "Private employee",
            "Government employee",
            "Self-employed",
            "Unemployed"
          ]),
        mother_education_level: Enum.random(["UG", "PG", "NA"]),
        time_of_device_availability:
          Enum.random(["Between 8am-10am", "Between 5pm-7pm", "Between 10pm-11pm"]),
        has_internet_access: Enum.random(["yes", "no"]),
        primary_smartphone_owner: Enum.random(["Father", "Mother"]),
        primary_smartphone_owner_profession: Enum.random(["Employed", "Unemployed"]),
        is_dropper: Enum.random([true, false]),
        contact_hours_per_week: Enum.random(20..48),
        guardian_name: Person.name(),
        guardian_relation: Enum.random(["Parent", "Sibling", "Aunt", "Uncle"]),
        guardian_phone: Phone.PtPt.number(),
        guardian_education_level: Enum.random(["UG", "PG", "NA"]),
        guardian_profession:
          Enum.random(["Self-employed", "Unemployed", "Private employee", "Government employee"]),
        has_category_certificate: Enum.random([true, false]),
        category_certificate: Seed.random_alphanumeric(),
        physically_handicapped_certificate: Seed.random_alphanumeric(),
        annual_family_income: Enum.random(["1LPA-3LPA", "3LPA-6LPA", ">6LPA"]),
        monthly_family_income: Enum.random(["5K-20K", "20K-50K", ">50K"]),
        number_of_smartphones: Enum.random(["1", "2", "3", "4", ">4"]),
        family_type: Enum.random(["Joint", "Nuclear", "Other"]),
        number_of_four_wheelers: Enum.random(["1", "2", "3", "4", ">4"]),
        number_of_two_wheelers: Enum.random(["1", "2", "3", "4", ">4"]),
        has_air_conditioner: Enum.random([true, false]),
        goes_for_tuition_or_other_coaching: Enum.random(["yes", "no"]),
        know_about_avanti: Enum.random(["yes", "no"]),
        percentage_in_grade_10_science:
          Enum.random([">49%", "50-59%", "60-69%", "70-79%", "80-89%", ">90%"]),
        percentage_in_grade_10_math:
          Enum.random([">49%", "50-59%", "60-69%", "70-79%", "80-89%", ">90%"]),
        percentage_in_grade_10_english:
          Enum.random([">49%", "50-59%", "60-69%", "70-79%", "80-89%", ">90%"]),
        grade_10_marksheet: Seed.random_alphanumeric(),
        photo: Seed.random_alphanumeric()
      })

    student
  end

  def create_school() do
    {:ok, school} =
      Schools.create_school(%{
        code: Enum.random(["KV", "DAV", "Navodaya"]),
        name: Enum.random(["Kendriya Vidyalaya", "Dayanand Anglo Vedic", "Navodaya"]),
        udise_code:
          Enum.random([
            "05040120901",
            "05040112401",
            "05040128901",
            "05040106001",
            "070501ND201",
            "070503ND902",
            "070512ND601",
            "070511ND101",
            "070507ND606",
            "070507ND302"
          ]),
        type: Enum.random(["Open", "Full-time"]),
        category: Enum.random(["Private", "Government", "Semi-government"]),
        region: Enum.random(["Urban", "Rural"]),
        state_code: Enum.random(["HR", "AS", "CT", "UK", "GJ", "DL", "HP"]),
        state:
          Enum.random([
            "HARYANA",
            "ASSAM",
            "CHATTISGARH",
            "UTTARAKHAND",
            "GUJRAT",
            "DELHI",
            "HIMACHAL PRADESH"
          ]),
        district_code: Enum.random(["0504", "0701", "0707"]),
        district: Enum.random(["TEHRI GARHWAL", "NORTH WEST DELHI", "WEST DELHI"]),
        block_code: Enum.random(["070501", "070502", "070503", "070507", "070104", "070106"]),
        block_name: Enum.random(["DOE", "DOEAIDED", "DOEUNAIDED", "NDMC", "MCD", "MCDUNAIDED"]),
        board: Enum.random(["ICSE", "CBSE", "State Board"]),
        board_medium: Enum.random(["English", "Hindi"])
      })

    school
  end

  def create_teacher() do
    school = Schools.School |> offset(^Enum.random(1..9)) |> limit(1) |> Repo.one()
    user = Seed.create_user()
    manager = Users.User |> offset(^Enum.random(1..99)) |> limit(1) |> Repo.one()

    {:ok, teacher} =
      Users.create_teacher(%{
        designation: Enum.random(["Teacher", "Principal", "Headmaster"]),
        subject: Enum.random(["Maths", "Science", "Commerce", "Arts"]),
        grade: Enum.random(["KG", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]),
        user_id: user.id,
        school_id: school.id,
        manager_id: manager.id,
        uuid: Seed.random_alphanumeric()
      })

    teacher
  end

  def create_enrollment_record() do
    school = Schools.School |> offset(^Enum.random(1..9)) |> limit(1) |> Repo.one()
    student = Users.Student |> offset(^Enum.random(1..99)) |> limit(1) |> Repo.one()
    group = Seed.create_group_type()

    {:ok, enrollment_record} =
      Schools.create_enrollment_record(%{
        grade: Enum.random(["KG", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]),
        board_medium: Enum.random(["ICSE", "CBSE", "State Board"]),
        academic_year:
          Enum.random([
            "2010-11",
            "2011-12",
            "2012-13",
            "2013-14",
            "2014-15",
            "2015-16",
            "2016-17",
            "2017-18",
            "2018-19",
            "2019-20",
            "2020-21",
            "2020-22"
          ]),
        is_current: Enum.random([true, false]),
        student_id: student.id,
        school_id: school.id,
        group_id: group.id,
        date_of_school_enrollment:
          Faker.DateTime.between(~N[2015-05-19 00:00:00], ~N[2022-10-19 00:00:00]),
        date_of_group_enrollment:
          Faker.DateTime.between(~N[2015-05-19 00:00:00], ~N[2022-10-19 00:00:00])
      })

    enrollment_record
  end

  def create_group_session() do
    session = Sessions.Session |> offset(^Enum.random(1..49)) |> limit(1) |> Repo.one()
    group_type = Seed.create_group_type()

    {:ok, group_session} =
      GroupSessions.create_group_session(%{
        group_type_id: group_type.id,
        session_id: session.id
      })

    group_session
  end

  def create_group_user() do
    group_type = Seed.create_group_type()
    user = Seed.create_user()
    manager = Users.User |> offset(^Enum.random(1..99)) |> limit(1) |> Repo.one()

    {:ok, group_user} =
      GroupUsers.create_group_user(%{
        group_type_id: group_type.id,
        user_id: user.id,
        manager_id: manager.id,
        date_of_joining: Faker.DateTime.between(~N[2015-05-19 00:00:00], ~N[2022-10-19 00:00:00]),
        student_language: Enum.random(["English", "Hindi"])
      })

    group_user
  end

  def create_group_type() do
    {:ok, group_type} =
      GroupTypes.create_group_type(%{
        type: Enum.random(["batch", "program", "group"]),
        child_id: Enum.random(1..50)
      })

    group_type
  end

  def create_form_schema() do
    {:ok, group_type} =
      FormSchemas.create_form_schema(%{
        name: Person.name(),
        attributes: %{
          "label" => Enum.random(["First Name", "Middle Name", "Last Name"])
        }
      })

    group_type
  end

  def create_tag() do
    {:ok, tag} =
      Tags.create_tag(%{
        name: Person.name(),
        description: Faker.Lorem.sentence()
      })

    tag
  end

  def create_curriculum() do
    tag = Tags.Tag |> offset(^Enum.random(1..9)) |> limit(1) |> Repo.one()

    {:ok, curriculum} =
      Curriculums.create_curriculum(%{
        name: Faker.Lorem.word(),
        code: Faker.Lorem.word(),
        tag_id: tag.id
      })

    curriculum
  end

  def create_grade() do
    tag = Tags.Tag |> offset(^Enum.random(1..9)) |> limit(1) |> Repo.one()

    {:ok, grade} =
      Grades.create_grade(%{
        number: Enum.random([9, 10, 11, 12]),
        tag_id: tag.id
      })

    grade
  end

  def create_subject() do
    tag = Tags.Tag |> offset(^Enum.random(1..9)) |> limit(1) |> Repo.one()

    {:ok, subject} =
      Subjects.create_subject(%{
        name: Enum.random(["Physics", "Chemistry", "Maths", "Biology"]),
        code: Faker.Lorem.word(),
        tag_id: tag.id
      })

    subject
  end

  def create_chapter() do
    grade = Grades.Grade |> offset(^Enum.random(1..9)) |> limit(1) |> Repo.one()
    subject = Subjects.Subject |> offset(^Enum.random(1..9)) |> limit(1) |> Repo.one()
    tag = Tags.Tag |> offset(^Enum.random(1..9)) |> limit(1) |> Repo.one()

    {:ok, chapter} =
      Chapters.create_chapter(%{
        name:
          Enum.random([
            "Electrostatics",
            "Electronic Devices",
            "Electrochemistry",
            "Polymers",
            "Differential Equations"
          ]),
        code: Faker.Lorem.word(),
        grade_id: grade.id,
        subject_id: subject.id,
        tag_id: tag.id
      })

    chapter
  end

  def create_topic() do
    grade = Grades.Grade |> offset(^Enum.random(1..9)) |> limit(1) |> Repo.one()
    chapter = Chapters.Chapter |> offset(^Enum.random(1..9)) |> limit(1) |> Repo.one()
    tag = Tags.Tag |> offset(^Enum.random(1..9)) |> limit(1) |> Repo.one()

    {:ok, topic} =
      Topics.create_topic(%{
        name:
          Enum.random([
            "Coulomb's Law",
            "Transistors",
            "Electrolysis",
            "Hydrocarbons",
            "Determinant Properties"
          ]),
        code: Faker.Lorem.word(),
        grade_id: grade.id,
        chapter_id: chapter.id,
        tag_id: tag.id
      })

    topic
  end

  def create_concept() do
    topic = Topics.Topic |> offset(^Enum.random(1..9)) |> limit(1) |> Repo.one()
    tag = Tags.Tag |> offset(^Enum.random(1..9)) |> limit(1) |> Repo.one()

    {:ok, concept} =
      Concepts.create_concept(%{
        name:
          Enum.random([
            "Electric Field Lines",
            "Transistor Amplification",
            "Oxidation and Reduction",
            "Polymer Structures",
            "Rolle's Theorem and Mean Value Theorem"
          ]),
        topic_id: 1,
        tag_id: 1
      })

    concept
  end

  def create_learning_objective() do
    concept = Concepts.Concept |> offset(^Enum.random(1..9)) |> limit(1) |> Repo.one()
    tag = Tags.Tag |> offset(^Enum.random(1..9)) |> limit(1) |> Repo.one()

    {:ok, learning_objective} =
      LearningObjectives.create_learning_objective(%{
        title:
          Enum.random([
            "Calculate the electrostatic force between two point charges using Coulomb's Law and understand its dependence on charge and distance",
            "Explain the properties and behavior of semiconductor materials, including their role in the operation of diodes and transistors",
            "Define oxidation and reduction reactions, identify redox reactions, and balance chemical equations involving electron transfer",
            "Classify hydrocarbons into alkanes, alkenes, and alkynes based on their structure and understand the nomenclature of organic compounds",
            "Calculate the inverse of a square matrix and understand the conditions under which a matrix is invertible"
          ]),
        concept_id: concept.id,
        tag_id: tag.id
      })

    learning_objective
  end

  def create_source() do
    tag = Tags.Tag |> offset(^Enum.random(1..9)) |> limit(1) |> Repo.one()

    {:ok, source} =
      Sources.create_source(%{
        name:
          Enum.random([
            "youtube",
            "CMS",
            "plio",
            "tictaclearn",
            "diksha"
          ]),
        link: Seed.random_alphanumeric(),
        tag_id: tag.id
      })

    source
  end

  def create_purpose() do
    tag = Tags.Tag |> offset(^Enum.random(1..9)) |> limit(1) |> Repo.one()

    {:ok, purpose} =
      Purposes.create_purpose(%{
        name:
          Enum.random([
            "introVideo",
            "conceptVideo",
            "problemSolvingVideo",
            "learningModule ",
            "conceptTest"
          ]),
        description: Faker.Lorem.sentence(),
        tag_id: tag.id
      })

    purpose
  end

  def create_resource() do
    curriculum = Curriculums.Curriculum |> offset(^Enum.random(1..9)) |> limit(1) |> Repo.one()
    chapter = Chapters.Chapter |> offset(^Enum.random(1..9)) |> limit(1) |> Repo.one()
    topic = Topics.Topic |> offset(^Enum.random(1..9)) |> limit(1) |> Repo.one()
    source = Sources.Source |> offset(^Enum.random(1..9)) |> limit(1) |> Repo.one()
    purpose = Purposes.Purpose |> offset(^Enum.random(1..9)) |> limit(1) |> Repo.one()
    concept = Concepts.Concept |> offset(^Enum.random(1..9)) |> limit(1) |> Repo.one()

    learning_objective =
      LearningObjectives.LearningObjective |> offset(^Enum.random(1..9)) |> limit(1) |> Repo.one()

    tag = Tags.Tag |> offset(^Enum.random(1..9)) |> limit(1) |> Repo.one()

    {:ok, resource} =
      Resources.create_resource(%{
        name:
          Enum.random([
            "1. 9C01 Introduction - हमारे आस पास के पदार्थ | Matter in our Surroundings",
            "2. 9C01.1 CV1 पदार्थ क्या है? | What is matter?",
            "3. 9C01.1 CV2 पदार्थ की भौतिक प्रकृति | Physical Nature of Matter",
            "4. 9C01.1 CV3 पदार्थ के कण | Particles of Matter ",
            "5. 9C01.1 CV4 पदार्थ के कण - क्रियाकलाप | Particles of Matter - Activity"
          ]),
        type: Enum.random(["video", "test"]),
        type_params: %{
          "duration" => Enum.random(["30 min", "45 min", "1 hr"])
        },
        difficulty_level: Enum.random(["easy", "medium", "hard"]),
        curriculum_id: curriculum.id,
        chapter_id: chapter.id,
        topic_id: topic.id,
        source_id: source.id,
        purpose_id: purpose.id,
        concept_id: concept.id,
        learning_objective_id: learning_objective.id,
        tag_id: tag.id
      })

    resource
  end
end

Repo.delete_all(Users.Teacher)
Repo.delete_all(Schools.EnrollmentRecord)
Repo.delete_all(Users.Student)
Repo.delete_all(Schools.School)
Repo.delete_all(Sessions.UserSession)
Repo.delete_all(Sessions.SessionOccurrence)
Repo.delete_all(Groups.GroupSession)
Repo.delete_all(Groups.GroupUser)
Repo.delete_all(Sessions.Session)
Repo.delete_all(Groups.GroupType)
Repo.delete_all(Batches.BatchProgram)
Repo.delete_all(Programs.Program)
Repo.delete_all(Groups.Group)
Repo.delete_all(Users.User)
Repo.delete_all(Batches.Batch)
Repo.delete_all(Curriculums.Curriculum)
Repo.delete_all(Grades.Grade)
Repo.delete_all(Subjects.Subject)
Repo.delete_all(Chapters.Chapter)
Repo.delete_all(Topics.Topic)
Repo.delete_all(Concepts.Concept)
Repo.delete_all(LearningObjectives.LearningObjective)
Repo.delete_all(Sources.Source)
Repo.delete_all(Purposes.Purpose)
Repo.delete_all(Resources.Resource)
Repo.delete_all(Tags.Tag)

if Mix.env() == :dev do
  # create some users
  for num <- 1..100 do
    Seed.create_user()
  end

  # create some groups
  for count <- 1..5 do
    group = Seed.create_group()
  end

  # create some sessions
  for count <- 1..50 do
    Seed.create_session()
  end

  # create some sessions occurences and user-session mappings
  for count <- 1..100 do
    Seed.create_session_occurrence()
  end

  # create some user session-occurence mappings
  for count <- 1..200 do
    Seed.create_user_session()
  end

  # create some user session-occurence mappings
  for count <- 1..10 do
    Seed.create_school()
  end

  # create some students
  for count <- 1..100 do
    Seed.create_student()
  end

  # create some enrollment records for students
  for count <- 1..200 do
    Seed.create_enrollment_record()
  end

  # create some teachers
  for count <- 1..9 do
    Seed.create_teacher()
  end

  # create some group_user
  for count <- 1..100 do
    Seed.create_group_user()
  end

  # create some group_session
  for count <- 1..100 do
    Seed.create_group_session()
  end

  # create some program
  for count <- 1..100 do
    Seed.create_program()
  end

  # create some batch
  for count <- 1..100 do
    Seed.create_batch()
  end

  # create some batch_program
  for count <- 1..100 do
    Seed.create_batch_program()
  end

  # create some group_type
  for count <- 1..100 do
    Seed.create_group_type()
  end

  # create some form_schema
  for count <- 1..100 do
    Seed.create_form_schema()
  end

  # create some tag
  for count <- 1..100 do
    Seed.create_tag()
  end

  # create some curriculum
  for count <- 1..100 do
    Seed.create_curriculum()
  end

  # create some grade
  for count <- 1..100 do
    Seed.create_grade()
  end

  # create some subject
  for count <- 1..100 do
    Seed.create_subject()
  end

  # create some chapter
  for count <- 1..100 do
    Seed.create_chapter()
  end

  # create some topic
  for count <- 1..100 do
    Seed.create_topic()
  end

  # create some concept
  for count <- 1..100 do
    Seed.create_concept()
  end

  # create some learning_objective
  for count <- 1..100 do
    Seed.create_learning_objective()
  end

  # create some source
  for count <- 1..100 do
    Seed.create_source()
  end

  # create some purpose
  for count <- 1..100 do
    Seed.create_purpose()
  end

  # create some resource
  for count <- 1..100 do
    Seed.create_resource()
  end
end
