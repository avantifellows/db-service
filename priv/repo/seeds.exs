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

  def create_session_occurence() do
    session = Sessions.Session |> offset(^Enum.random(1..49)) |> limit(1) |> Repo.one()

    {:ok, session_occurence} =
      Sessions.create_session_occurence(%{
        session_fk: session.id,
        start_time: session.start_time,
        end_time: session.end_time,
        session_id: Seed.random_alphanumeric()
      })

    session_occurence
  end

  def create_user_session() do
    session_occurrence =
      Sessions.SessionOccurence |> offset(^Enum.random(1..99)) |> limit(1) |> Repo.one()

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
        family_income: Enum.random(["1LPA-3LPA", "3LPA-6LPA", ">6LPA"]),
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
        time_of_device_availability: Faker.DateTime.forward(Enum.random(1..10)),
        has_internet_access: Enum.random([true, false]),
        primary_smartphone_owner: Enum.random(["Father", "Mother"]),
        primary_smartphone_owner_profession: Enum.random(["Employed", "Unemployed"]),
        is_dropper: Enum.random([true, false]),
        contact_hours_per_week: Enum.random(20..48)
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
end

Repo.delete_all(Users.Teacher)
Repo.delete_all(Schools.EnrollmentRecord)
Repo.delete_all(Users.Student)
Repo.delete_all(Schools.School)
Repo.delete_all(Sessions.UserSession)
Repo.delete_all(Sessions.SessionOccurence)
Repo.delete_all(Groups.GroupSession)
Repo.delete_all(Groups.GroupUser)
Repo.delete_all(Sessions.Session)
Repo.delete_all(Groups.GroupType)
Repo.delete_all(Batches.BatchProgram)
Repo.delete_all(Programs.Program)
Repo.delete_all(Groups.Group)
Repo.delete_all(Users.User)
Repo.delete_all(Batches.Batch)

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
    Seed.create_session_occurence()
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
end
