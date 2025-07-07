defmodule DbserviceWeb.StudentProfileJSON do
  alias DbserviceWeb.UserProfileJSON

  def index(%{student_profile: student_profile}) do
    for(sp <- student_profile, do: render(sp))
  end

  def show(%{student_profile: student_profile}) do
    render(student_profile)
  end

  def show_student_profile_with_user_profile(%{student_profile: student_profile}) do
    student_profile_with_user_profile(student_profile)
  end

  def render(student_profile) do
    student_profile = Dbservice.Repo.preload(student_profile, :user_profile)

    %{
      id: student_profile.id,
      student_id: student_profile.student_id,
      student_fk: student_profile.student_fk,
      took_test_atleast_once: student_profile.took_test_atleast_once,
      took_class_atleast_once: student_profile.took_class_atleast_once,
      total_number_of_tests: student_profile.total_number_of_tests,
      total_number_of_live_classes: student_profile.total_number_of_live_classes,
      attendance_in_classes_current_year: student_profile.attendance_in_classes_current_year,
      classes_activity_cohort: student_profile.classes_activity_cohort,
      attendance_in_tests_current_year: student_profile.attendance_in_tests_current_year,
      tests_activity_cohort: student_profile.tests_activity_cohort,
      performance_trend_in_fst: student_profile.performance_trend_in_fst,
      max_batch_score_in_latest_test: student_profile.max_batch_score_in_latest_test,
      average_batch_score_in_latest_test: student_profile.average_batch_score_in_latest_test,
      tests_number_of_correct_questions: student_profile.tests_number_of_correct_questions,
      tests_number_of_wrong_questions: student_profile.tests_number_of_wrong_questions,
      tests_number_of_skipped_questions: student_profile.tests_number_of_skipped_questions,
      user_profile_id: student_profile.user_profile_id,
      user_profile:
        if(student_profile.user_profile,
          do: UserProfileJSON.render(student_profile.user_profile),
          else: nil
        )
    }
  end

  def student_profile_with_user_profile(student_profile) do
    student_profile = Dbservice.Repo.preload(student_profile, :user_profile)

    %{
      id: student_profile.id,
      student_id: student_profile.student_id,
      student_fk: student_profile.student_fk,
      took_test_atleast_once: student_profile.took_test_atleast_once,
      took_class_atleast_once: student_profile.took_class_atleast_once,
      total_number_of_tests: student_profile.total_number_of_tests,
      total_number_of_live_classes: student_profile.total_number_of_live_classes,
      attendance_in_classes_current_year: student_profile.attendance_in_classes_current_year,
      classes_activity_cohort: student_profile.classes_activity_cohort,
      attendance_in_tests_current_year: student_profile.attendance_in_tests_current_year,
      tests_activity_cohort: student_profile.tests_activity_cohort,
      performance_trend_in_fst: student_profile.performance_trend_in_fst,
      max_batch_score_in_latest_test: student_profile.max_batch_score_in_latest_test,
      average_batch_score_in_latest_test: student_profile.average_batch_score_in_latest_test,
      tests_number_of_correct_questions: student_profile.tests_number_of_correct_questions,
      tests_number_of_wrong_questions: student_profile.tests_number_of_wrong_questions,
      tests_number_of_skipped_questions: student_profile.tests_number_of_skipped_questions,
      user_profile_id: student_profile.user_profile_id,
      user_profile:
        if(student_profile.user_profile,
          do: UserProfileJSON.render(student_profile.user_profile),
          else: nil
        )
    }
  end
end
