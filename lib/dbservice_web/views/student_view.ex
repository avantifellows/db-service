defmodule DbserviceWeb.StudentView do
  use DbserviceWeb, :view
  alias DbserviceWeb.StudentView
  alias DbserviceWeb.UserView
  alias Dbservice.Repo

  def render("index.json", %{student: student}) do
    render_many(student, StudentView, "student.json")
  end

  def render("show.json", %{student: student}) do
    render_one(student, StudentView, "student.json")
  end

  def render("show_with_user.json", %{student: student}) do
    render_many(student, StudentView, "student_with_user.json")
  end

  def render("student.json", %{student: student}) do
    student = Repo.preload(student, :user)

    %{
      id: student.id,
      student_id: student.student_id,
      father_name: student.father_name,
      father_phone: student.father_phone,
      mother_name: student.mother_name,
      mother_phone: student.mother_phone,
      category: student.category,
      stream: student.stream,
      physically_handicapped: student.physically_handicapped,
      family_income: student.family_income,
      father_profession: student.father_profession,
      father_education_level: student.father_education_level,
      mother_profession: student.mother_profession,
      mother_education_level: student.mother_education_level,
      time_of_device_availability: student.time_of_device_availability,
      has_internet_access: student.has_internet_access,
      primary_smartphone_owner: student.primary_smartphone_owner,
      primary_smartphone_owner_profession: student.primary_smartphone_owner_profession,
      user: render_one(student.user, UserView, "user.json")
    }
  end

  def render("student_with_user.json", %{student: student}) do
    student = Repo.preload(student, :user)

    %{
      id: student.id,
      student_id: student.student_id,
      father_name: student.father_name,
      father_phone: student.father_phone,
      mother_name: student.mother_name,
      mother_phone: student.mother_phone,
      category: student.category,
      stream: student.stream,
      physically_handicapped: student.physically_handicapped,
      family_income: student.family_income,
      father_profession: student.father_profession,
      father_education_level: student.father_education_level,
      mother_profession: student.mother_profession,
      mother_education_level: student.mother_education_level,
      time_of_device_availability: student.time_of_device_availability,
      has_internet_access: student.has_internet_access,
      primary_smartphone_owner: student.primary_smartphone_owner,
      primary_smartphone_owner_profession: student.primary_smartphone_owner_profession,
      user: render_one(student.user, UserView, "user.json")
    }
  end
end
