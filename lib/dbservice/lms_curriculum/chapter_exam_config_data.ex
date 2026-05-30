defmodule Dbservice.LmsCurriculum.ChapterExamConfigData do
  @moduledoc """
  Embedded 2026-27 LMS Chapter Exam Config dataset.

  Source files:
  - Intervention Timemap 2026-27 - Physics.csv
  - Intervention Timemap 2026-27 - Chemsitry.csv
  - Intervention Timemap 2026-27 - Mathematics.csv
  - Intervention Timemap 2026-27 - Biology.csv
  """

  @version "2026-27-v1"
  @expected_counts %{"Physics" => 87, "Chemistry" => 96, "Maths" => 56, "Biology" => 38}

  @rows [
    %{
      chapter_code: "11P1",
      chapter_name: "Mathematical Tools",
      grade: 11,
      subject: "Physics",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 600,
      coverage_sequence: 1
    },
    %{
      chapter_code: "11P1",
      chapter_name: "Mathematical Tools",
      grade: 11,
      subject: "Physics",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 840,
      coverage_sequence: 1
    },
    %{
      chapter_code: "11P1",
      chapter_name: "Mathematical Tools",
      grade: 11,
      subject: "Physics",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 600,
      coverage_sequence: 1
    },
    %{
      chapter_code: "11P2",
      chapter_name: "Units, Dimensions and Errors",
      grade: 11,
      subject: "Physics",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 480,
      coverage_sequence: 2
    },
    %{
      chapter_code: "11P2",
      chapter_name: "Units, Dimensions and Errors",
      grade: 11,
      subject: "Physics",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 600,
      coverage_sequence: 2
    },
    %{
      chapter_code: "11P2",
      chapter_name: "Units, Dimensions and Errors",
      grade: 11,
      subject: "Physics",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 420,
      coverage_sequence: 2
    },
    %{
      chapter_code: "11P3",
      chapter_name: "Motion in One Dimension",
      grade: 11,
      subject: "Physics",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 600,
      coverage_sequence: 3
    },
    %{
      chapter_code: "11P3",
      chapter_name: "Motion in One Dimension",
      grade: 11,
      subject: "Physics",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 840,
      coverage_sequence: 3
    },
    %{
      chapter_code: "11P3",
      chapter_name: "Motion in One Dimension",
      grade: 11,
      subject: "Physics",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 480,
      coverage_sequence: 3
    },
    %{
      chapter_code: "11P4",
      chapter_name: "Motion in Two Dimension",
      grade: 11,
      subject: "Physics",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 720,
      coverage_sequence: 4
    },
    %{
      chapter_code: "11P4",
      chapter_name: "Motion in Two Dimension",
      grade: 11,
      subject: "Physics",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 960,
      coverage_sequence: 4
    },
    %{
      chapter_code: "11P4",
      chapter_name: "Motion in Two Dimension",
      grade: 11,
      subject: "Physics",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 600,
      coverage_sequence: 4
    },
    %{
      chapter_code: "11P5",
      chapter_name: "Newton's Laws of Motion and Friction",
      grade: 11,
      subject: "Physics",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 960,
      coverage_sequence: 5
    },
    %{
      chapter_code: "11P5",
      chapter_name: "Newton's Laws of Motion and Friction",
      grade: 11,
      subject: "Physics",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1200,
      coverage_sequence: 5
    },
    %{
      chapter_code: "11P5",
      chapter_name: "Newton's Laws of Motion and Friction",
      grade: 11,
      subject: "Physics",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 900,
      coverage_sequence: 5
    },
    %{
      chapter_code: "11P6",
      chapter_name: "Work, Power and Energy",
      grade: 11,
      subject: "Physics",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 960,
      coverage_sequence: 6
    },
    %{
      chapter_code: "11P6",
      chapter_name: "Work, Power and Energy",
      grade: 11,
      subject: "Physics",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1200,
      coverage_sequence: 6
    },
    %{
      chapter_code: "11P6",
      chapter_name: "Work, Power and Energy",
      grade: 11,
      subject: "Physics",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 840,
      coverage_sequence: 6
    },
    %{
      chapter_code: "11P7",
      chapter_name: "Circular Motion",
      grade: 11,
      subject: "Physics",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 600,
      coverage_sequence: 7
    },
    %{
      chapter_code: "11P7",
      chapter_name: "Circular Motion",
      grade: 11,
      subject: "Physics",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 840,
      coverage_sequence: 7
    },
    %{
      chapter_code: "11P7",
      chapter_name: "Circular Motion",
      grade: 11,
      subject: "Physics",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 480,
      coverage_sequence: 7
    },
    %{
      chapter_code: "11P8",
      chapter_name: "Centre of Mass",
      grade: 11,
      subject: "Physics",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 720,
      coverage_sequence: 8
    },
    %{
      chapter_code: "11P8",
      chapter_name: "Centre of Mass",
      grade: 11,
      subject: "Physics",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 960,
      coverage_sequence: 8
    },
    %{
      chapter_code: "11P8",
      chapter_name: "Centre of Mass",
      grade: 11,
      subject: "Physics",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 480,
      coverage_sequence: 8
    },
    %{
      chapter_code: "11P9",
      chapter_name: "Rigid Body Dynamics",
      grade: 11,
      subject: "Physics",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 960,
      coverage_sequence: 9
    },
    %{
      chapter_code: "11P9",
      chapter_name: "Rigid Body Dynamics",
      grade: 11,
      subject: "Physics",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1200,
      coverage_sequence: 9
    },
    %{
      chapter_code: "11P9",
      chapter_name: "Rigid Body Dynamics",
      grade: 11,
      subject: "Physics",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 900,
      coverage_sequence: 9
    },
    %{
      chapter_code: "11P10",
      chapter_name: "Gravitation",
      grade: 11,
      subject: "Physics",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 720,
      coverage_sequence: 10
    },
    %{
      chapter_code: "11P10",
      chapter_name: "Gravitation",
      grade: 11,
      subject: "Physics",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 960,
      coverage_sequence: 10
    },
    %{
      chapter_code: "11P10",
      chapter_name: "Gravitation",
      grade: 11,
      subject: "Physics",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 600,
      coverage_sequence: 10
    },
    %{
      chapter_code: "11P11",
      chapter_name: "Mechanical Properties of Solids",
      grade: 11,
      subject: "Physics",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 480,
      coverage_sequence: 11
    },
    %{
      chapter_code: "11P11",
      chapter_name: "Mechanical Properties of Solids",
      grade: 11,
      subject: "Physics",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 660,
      coverage_sequence: 11
    },
    %{
      chapter_code: "11P11",
      chapter_name: "Mechanical Properties of Solids",
      grade: 11,
      subject: "Physics",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 420,
      coverage_sequence: 11
    },
    %{
      chapter_code: "11P12",
      chapter_name: "Mechanical Properties of Fluids",
      grade: 11,
      subject: "Physics",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 960,
      coverage_sequence: 12
    },
    %{
      chapter_code: "11P12",
      chapter_name: "Mechanical Properties of Fluids",
      grade: 11,
      subject: "Physics",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1320,
      coverage_sequence: 12
    },
    %{
      chapter_code: "11P12",
      chapter_name: "Mechanical Properties of Fluids",
      grade: 11,
      subject: "Physics",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 840,
      coverage_sequence: 12
    },
    %{
      chapter_code: "11P13",
      chapter_name: "Thermal Properties of Matter",
      grade: 11,
      subject: "Physics",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 600,
      coverage_sequence: 13
    },
    %{
      chapter_code: "11P13",
      chapter_name: "Thermal Properties of Matter",
      grade: 11,
      subject: "Physics",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 900,
      coverage_sequence: 13
    },
    %{
      chapter_code: "11P13",
      chapter_name: "Thermal Properties of Matter",
      grade: 11,
      subject: "Physics",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 480,
      coverage_sequence: 13
    },
    %{
      chapter_code: "11P14",
      chapter_name: "Kinetic Theory of Gases and Thermodynamics",
      grade: 11,
      subject: "Physics",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 960,
      coverage_sequence: 14
    },
    %{
      chapter_code: "11P14",
      chapter_name: "Kinetic Theory of Gases and Thermodynamics",
      grade: 11,
      subject: "Physics",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1200,
      coverage_sequence: 14
    },
    %{
      chapter_code: "11P14",
      chapter_name: "Kinetic Theory of Gases and Thermodynamics",
      grade: 11,
      subject: "Physics",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 960,
      coverage_sequence: 14
    },
    %{
      chapter_code: "11P15",
      chapter_name: "Simple Harmonic Motion",
      grade: 11,
      subject: "Physics",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 840,
      coverage_sequence: 15
    },
    %{
      chapter_code: "11P15",
      chapter_name: "Simple Harmonic Motion",
      grade: 11,
      subject: "Physics",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1140,
      coverage_sequence: 15
    },
    %{
      chapter_code: "11P15",
      chapter_name: "Simple Harmonic Motion",
      grade: 11,
      subject: "Physics",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 720,
      coverage_sequence: 15
    },
    %{
      chapter_code: "11P16",
      chapter_name: "Waves",
      grade: 11,
      subject: "Physics",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 840,
      coverage_sequence: 16
    },
    %{
      chapter_code: "11P16",
      chapter_name: "Waves",
      grade: 11,
      subject: "Physics",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1200,
      coverage_sequence: 16
    },
    %{
      chapter_code: "11P16",
      chapter_name: "Waves",
      grade: 11,
      subject: "Physics",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 840,
      coverage_sequence: 16
    },
    %{
      chapter_code: "12P17",
      chapter_name: "Electric Charges and Fields",
      grade: 12,
      subject: "Physics",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 960,
      coverage_sequence: 17
    },
    %{
      chapter_code: "12P17",
      chapter_name: "Electric Charges and Fields",
      grade: 12,
      subject: "Physics",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1320,
      coverage_sequence: 17
    },
    %{
      chapter_code: "12P17",
      chapter_name: "Electric Charges and Fields",
      grade: 12,
      subject: "Physics",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 960,
      coverage_sequence: 17
    },
    %{
      chapter_code: "12P18",
      chapter_name: "Electric Potential and Capacitance",
      grade: 12,
      subject: "Physics",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 840,
      coverage_sequence: 18
    },
    %{
      chapter_code: "12P18",
      chapter_name: "Electric Potential and Capacitance",
      grade: 12,
      subject: "Physics",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1320,
      coverage_sequence: 18
    },
    %{
      chapter_code: "12P18",
      chapter_name: "Electric Potential and Capacitance",
      grade: 12,
      subject: "Physics",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 720,
      coverage_sequence: 18
    },
    %{
      chapter_code: "12P19",
      chapter_name: "Current Electricity",
      grade: 12,
      subject: "Physics",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 1080,
      coverage_sequence: 19
    },
    %{
      chapter_code: "12P19",
      chapter_name: "Current Electricity",
      grade: 12,
      subject: "Physics",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1320,
      coverage_sequence: 19
    },
    %{
      chapter_code: "12P19",
      chapter_name: "Current Electricity",
      grade: 12,
      subject: "Physics",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 840,
      coverage_sequence: 19
    },
    %{
      chapter_code: "12P20",
      chapter_name: "Magnetic Effects of Electric Current and Magnetism",
      grade: 12,
      subject: "Physics",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 1080,
      coverage_sequence: 20
    },
    %{
      chapter_code: "12P20",
      chapter_name: "Magnetic Effects of Electric Current and Magnetism",
      grade: 12,
      subject: "Physics",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1320,
      coverage_sequence: 20
    },
    %{
      chapter_code: "12P20",
      chapter_name: "Magnetic Effects of Electric Current and Magnetism",
      grade: 12,
      subject: "Physics",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 960,
      coverage_sequence: 20
    },
    %{
      chapter_code: "12P21",
      chapter_name: "Electromagnetic induction",
      grade: 12,
      subject: "Physics",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 480,
      coverage_sequence: 21
    },
    %{
      chapter_code: "12P21",
      chapter_name: "Electromagnetic induction",
      grade: 12,
      subject: "Physics",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 720,
      coverage_sequence: 21
    },
    %{
      chapter_code: "12P21",
      chapter_name: "Electromagnetic induction",
      grade: 12,
      subject: "Physics",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 600,
      coverage_sequence: 21
    },
    %{
      chapter_code: "12P22",
      chapter_name: "Alternating Current",
      grade: 12,
      subject: "Physics",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 840,
      coverage_sequence: 22
    },
    %{
      chapter_code: "12P22",
      chapter_name: "Alternating Current",
      grade: 12,
      subject: "Physics",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 960,
      coverage_sequence: 22
    },
    %{
      chapter_code: "12P22",
      chapter_name: "Alternating Current",
      grade: 12,
      subject: "Physics",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 720,
      coverage_sequence: 22
    },
    %{
      chapter_code: "12P23",
      chapter_name: "Ray Optics",
      grade: 12,
      subject: "Physics",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 1080,
      coverage_sequence: 23
    },
    %{
      chapter_code: "12P23",
      chapter_name: "Ray Optics",
      grade: 12,
      subject: "Physics",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1440,
      coverage_sequence: 23
    },
    %{
      chapter_code: "12P23",
      chapter_name: "Ray Optics",
      grade: 12,
      subject: "Physics",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 1080,
      coverage_sequence: 23
    },
    %{
      chapter_code: "12P24",
      chapter_name: "Wave Optics",
      grade: 12,
      subject: "Physics",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 720,
      coverage_sequence: 24
    },
    %{
      chapter_code: "12P24",
      chapter_name: "Wave Optics",
      grade: 12,
      subject: "Physics",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1080,
      coverage_sequence: 24
    },
    %{
      chapter_code: "12P24",
      chapter_name: "Wave Optics",
      grade: 12,
      subject: "Physics",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 600,
      coverage_sequence: 24
    },
    %{
      chapter_code: "12P25",
      chapter_name: "Modern Physics",
      grade: 12,
      subject: "Physics",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 960,
      coverage_sequence: 25
    },
    %{
      chapter_code: "12P25",
      chapter_name: "Modern Physics",
      grade: 12,
      subject: "Physics",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1200,
      coverage_sequence: 25
    },
    %{
      chapter_code: "12P25",
      chapter_name: "Modern Physics",
      grade: 12,
      subject: "Physics",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 720,
      coverage_sequence: 25
    },
    %{
      chapter_code: "12P26",
      chapter_name: "Nuclear Physics",
      grade: 12,
      subject: "Physics",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 360,
      coverage_sequence: 26
    },
    %{
      chapter_code: "12P26",
      chapter_name: "Nuclear Physics",
      grade: 12,
      subject: "Physics",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 840,
      coverage_sequence: 26
    },
    %{
      chapter_code: "12P26",
      chapter_name: "Nuclear Physics",
      grade: 12,
      subject: "Physics",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 360,
      coverage_sequence: 26
    },
    %{
      chapter_code: "12P27",
      chapter_name: "Semiconductor",
      grade: 12,
      subject: "Physics",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 480,
      coverage_sequence: 27
    },
    %{
      chapter_code: "12P27",
      chapter_name: "Semiconductor",
      grade: 12,
      subject: "Physics",
      exam_track: "jee_advanced",
      is_in_syllabus: false,
      prescribed_minutes: 0,
      coverage_sequence: 27
    },
    %{
      chapter_code: "12P27",
      chapter_name: "Semiconductor",
      grade: 12,
      subject: "Physics",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 480,
      coverage_sequence: 27
    },
    %{
      chapter_code: "12P28",
      chapter_name: "Electromagnetic Waves",
      grade: 12,
      subject: "Physics",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 360,
      coverage_sequence: 28
    },
    %{
      chapter_code: "12P28",
      chapter_name: "Electromagnetic Waves",
      grade: 12,
      subject: "Physics",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 480,
      coverage_sequence: 28
    },
    %{
      chapter_code: "12P28",
      chapter_name: "Electromagnetic Waves",
      grade: 12,
      subject: "Physics",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 300,
      coverage_sequence: 28
    },
    %{
      chapter_code: "12P29",
      chapter_name: "Experimental Skills",
      grade: 12,
      subject: "Physics",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 480,
      coverage_sequence: 29
    },
    %{
      chapter_code: "12P29",
      chapter_name: "Experimental Skills",
      grade: 12,
      subject: "Physics",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 0,
      coverage_sequence: 29
    },
    %{
      chapter_code: "12P29",
      chapter_name: "Experimental Skills",
      grade: 12,
      subject: "Physics",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 480,
      coverage_sequence: 29
    },
    %{
      chapter_code: "11C1",
      chapter_name: "Mole Concept",
      grade: 11,
      subject: "Chemistry",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 1080,
      coverage_sequence: 1
    },
    %{
      chapter_code: "11C1",
      chapter_name: "Mole Concept",
      grade: 11,
      subject: "Chemistry",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1320,
      coverage_sequence: 1
    },
    %{
      chapter_code: "11C1",
      chapter_name: "Mole Concept",
      grade: 11,
      subject: "Chemistry",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 1080,
      coverage_sequence: 1
    },
    %{
      chapter_code: "11C2",
      chapter_name: "Atomic Structure",
      grade: 11,
      subject: "Chemistry",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 1020,
      coverage_sequence: 2
    },
    %{
      chapter_code: "11C2",
      chapter_name: "Atomic Structure",
      grade: 11,
      subject: "Chemistry",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1380,
      coverage_sequence: 2
    },
    %{
      chapter_code: "11C2",
      chapter_name: "Atomic Structure",
      grade: 11,
      subject: "Chemistry",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 1020,
      coverage_sequence: 2
    },
    %{
      chapter_code: "11C3",
      chapter_name: "Periodic Table",
      grade: 11,
      subject: "Chemistry",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 780,
      coverage_sequence: 3
    },
    %{
      chapter_code: "11C3",
      chapter_name: "Periodic Table",
      grade: 11,
      subject: "Chemistry",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1020,
      coverage_sequence: 3
    },
    %{
      chapter_code: "11C3",
      chapter_name: "Periodic Table",
      grade: 11,
      subject: "Chemistry",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 780,
      coverage_sequence: 3
    },
    %{
      chapter_code: "11C4",
      chapter_name: "Chemical Bonding",
      grade: 11,
      subject: "Chemistry",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 1380,
      coverage_sequence: 4
    },
    %{
      chapter_code: "11C4",
      chapter_name: "Chemical Bonding",
      grade: 11,
      subject: "Chemistry",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1680,
      coverage_sequence: 4
    },
    %{
      chapter_code: "11C4",
      chapter_name: "Chemical Bonding",
      grade: 11,
      subject: "Chemistry",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 1200,
      coverage_sequence: 4
    },
    %{
      chapter_code: "11C5",
      chapter_name: "Gaseous State",
      grade: 11,
      subject: "Chemistry",
      exam_track: "jee_main",
      is_in_syllabus: false,
      prescribed_minutes: 0,
      coverage_sequence: 5
    },
    %{
      chapter_code: "11C5",
      chapter_name: "Gaseous State",
      grade: 11,
      subject: "Chemistry",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1200,
      coverage_sequence: 5
    },
    %{
      chapter_code: "11C5",
      chapter_name: "Gaseous State",
      grade: 11,
      subject: "Chemistry",
      exam_track: "neet",
      is_in_syllabus: false,
      prescribed_minutes: 0,
      coverage_sequence: 5
    },
    %{
      chapter_code: "11C6",
      chapter_name: "Thermodynamics",
      grade: 11,
      subject: "Chemistry",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 1200,
      coverage_sequence: 6
    },
    %{
      chapter_code: "11C6",
      chapter_name: "Thermodynamics",
      grade: 11,
      subject: "Chemistry",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1440,
      coverage_sequence: 6
    },
    %{
      chapter_code: "11C6",
      chapter_name: "Thermodynamics",
      grade: 11,
      subject: "Chemistry",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 1200,
      coverage_sequence: 6
    },
    %{
      chapter_code: "11C7",
      chapter_name: "Chemical Equilibrium",
      grade: 11,
      subject: "Chemistry",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 600,
      coverage_sequence: 7
    },
    %{
      chapter_code: "11C7",
      chapter_name: "Chemical Equilibrium",
      grade: 11,
      subject: "Chemistry",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 780,
      coverage_sequence: 7
    },
    %{
      chapter_code: "11C7",
      chapter_name: "Chemical Equilibrium",
      grade: 11,
      subject: "Chemistry",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 600,
      coverage_sequence: 7
    },
    %{
      chapter_code: "11C8",
      chapter_name: "Ionic Equilibrium",
      grade: 11,
      subject: "Chemistry",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 1020,
      coverage_sequence: 8
    },
    %{
      chapter_code: "11C8",
      chapter_name: "Ionic Equilibrium",
      grade: 11,
      subject: "Chemistry",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1380,
      coverage_sequence: 8
    },
    %{
      chapter_code: "11C8",
      chapter_name: "Ionic Equilibrium",
      grade: 11,
      subject: "Chemistry",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 1020,
      coverage_sequence: 8
    },
    %{
      chapter_code: "11C9",
      chapter_name: "Redox Reaction",
      grade: 11,
      subject: "Chemistry",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 840,
      coverage_sequence: 9
    },
    %{
      chapter_code: "11C9",
      chapter_name: "Redox Reaction",
      grade: 11,
      subject: "Chemistry",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1020,
      coverage_sequence: 9
    },
    %{
      chapter_code: "11C9",
      chapter_name: "Redox Reaction",
      grade: 11,
      subject: "Chemistry",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 660,
      coverage_sequence: 9
    },
    %{
      chapter_code: "11C10",
      chapter_name: "Hydrogen",
      grade: 11,
      subject: "Chemistry",
      exam_track: "jee_main",
      is_in_syllabus: false,
      prescribed_minutes: 0,
      coverage_sequence: 10
    },
    %{
      chapter_code: "11C10",
      chapter_name: "Hydrogen",
      grade: 11,
      subject: "Chemistry",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 720,
      coverage_sequence: 10
    },
    %{
      chapter_code: "11C10",
      chapter_name: "Hydrogen",
      grade: 11,
      subject: "Chemistry",
      exam_track: "neet",
      is_in_syllabus: false,
      prescribed_minutes: 0,
      coverage_sequence: 10
    },
    %{
      chapter_code: "11C11",
      chapter_name: "The s-Block Elements",
      grade: 11,
      subject: "Chemistry",
      exam_track: "jee_main",
      is_in_syllabus: false,
      prescribed_minutes: 0,
      coverage_sequence: 11
    },
    %{
      chapter_code: "11C11",
      chapter_name: "The s-Block Elements",
      grade: 11,
      subject: "Chemistry",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 600,
      coverage_sequence: 11
    },
    %{
      chapter_code: "11C11",
      chapter_name: "The s-Block Elements",
      grade: 11,
      subject: "Chemistry",
      exam_track: "neet",
      is_in_syllabus: false,
      prescribed_minutes: 0,
      coverage_sequence: 11
    },
    %{
      chapter_code: "11C12",
      chapter_name: "IUPAC Nomenclature and Isomerism",
      grade: 11,
      subject: "Chemistry",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 1380,
      coverage_sequence: 12
    },
    %{
      chapter_code: "11C12",
      chapter_name: "IUPAC Nomenclature and Isomerism",
      grade: 11,
      subject: "Chemistry",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1800,
      coverage_sequence: 12
    },
    %{
      chapter_code: "11C12",
      chapter_name: "IUPAC Nomenclature and Isomerism",
      grade: 11,
      subject: "Chemistry",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 1380,
      coverage_sequence: 12
    },
    %{
      chapter_code: "11C13",
      chapter_name: "General Organic Chemistry",
      grade: 11,
      subject: "Chemistry",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 1380,
      coverage_sequence: 13
    },
    %{
      chapter_code: "11C13",
      chapter_name: "General Organic Chemistry",
      grade: 11,
      subject: "Chemistry",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1800,
      coverage_sequence: 13
    },
    %{
      chapter_code: "11C13",
      chapter_name: "General Organic Chemistry",
      grade: 11,
      subject: "Chemistry",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 1380,
      coverage_sequence: 13
    },
    %{
      chapter_code: "11C14",
      chapter_name: "Hydrocarbons",
      grade: 11,
      subject: "Chemistry",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 1020,
      coverage_sequence: 14
    },
    %{
      chapter_code: "11C14",
      chapter_name: "Hydrocarbons",
      grade: 11,
      subject: "Chemistry",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1200,
      coverage_sequence: 14
    },
    %{
      chapter_code: "11C14",
      chapter_name: "Hydrocarbons",
      grade: 11,
      subject: "Chemistry",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 1020,
      coverage_sequence: 14
    },
    %{
      chapter_code: "11C15",
      chapter_name: "Environmental Chemistry",
      grade: 11,
      subject: "Chemistry",
      exam_track: "jee_main",
      is_in_syllabus: false,
      prescribed_minutes: 0,
      coverage_sequence: 15
    },
    %{
      chapter_code: "11C15",
      chapter_name: "Environmental Chemistry",
      grade: 11,
      subject: "Chemistry",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 300,
      coverage_sequence: 15
    },
    %{
      chapter_code: "11C15",
      chapter_name: "Environmental Chemistry",
      grade: 11,
      subject: "Chemistry",
      exam_track: "neet",
      is_in_syllabus: false,
      prescribed_minutes: 0,
      coverage_sequence: 15
    },
    %{
      chapter_code: "12C16",
      chapter_name: "The Solid State",
      grade: 11,
      subject: "Chemistry",
      exam_track: "jee_main",
      is_in_syllabus: false,
      prescribed_minutes: 0,
      coverage_sequence: 16
    },
    %{
      chapter_code: "12C16",
      chapter_name: "The Solid State",
      grade: 11,
      subject: "Chemistry",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 960,
      coverage_sequence: 16
    },
    %{
      chapter_code: "12C16",
      chapter_name: "The Solid State",
      grade: 11,
      subject: "Chemistry",
      exam_track: "neet",
      is_in_syllabus: false,
      prescribed_minutes: 0,
      coverage_sequence: 16
    },
    %{
      chapter_code: "12C17",
      chapter_name: "Solutions and Colligative Properties",
      grade: 12,
      subject: "Chemistry",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 780,
      coverage_sequence: 17
    },
    %{
      chapter_code: "12C17",
      chapter_name: "Solutions and Colligative Properties",
      grade: 12,
      subject: "Chemistry",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 960,
      coverage_sequence: 17
    },
    %{
      chapter_code: "12C17",
      chapter_name: "Solutions and Colligative Properties",
      grade: 12,
      subject: "Chemistry",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 780,
      coverage_sequence: 17
    },
    %{
      chapter_code: "12C18",
      chapter_name: "Electrochemistry",
      grade: 12,
      subject: "Chemistry",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 900,
      coverage_sequence: 18
    },
    %{
      chapter_code: "12C18",
      chapter_name: "Electrochemistry",
      grade: 12,
      subject: "Chemistry",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1200,
      coverage_sequence: 18
    },
    %{
      chapter_code: "12C18",
      chapter_name: "Electrochemistry",
      grade: 12,
      subject: "Chemistry",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 840,
      coverage_sequence: 18
    },
    %{
      chapter_code: "12C19",
      chapter_name: "Chemical Kinetics",
      grade: 12,
      subject: "Chemistry",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 900,
      coverage_sequence: 19
    },
    %{
      chapter_code: "12C19",
      chapter_name: "Chemical Kinetics",
      grade: 12,
      subject: "Chemistry",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1080,
      coverage_sequence: 19
    },
    %{
      chapter_code: "12C19",
      chapter_name: "Chemical Kinetics",
      grade: 12,
      subject: "Chemistry",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 840,
      coverage_sequence: 19
    },
    %{
      chapter_code: "12C20",
      chapter_name: "Surface Chemistry",
      grade: 12,
      subject: "Chemistry",
      exam_track: "jee_main",
      is_in_syllabus: false,
      prescribed_minutes: 0,
      coverage_sequence: 20
    },
    %{
      chapter_code: "12C20",
      chapter_name: "Surface Chemistry",
      grade: 12,
      subject: "Chemistry",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 480,
      coverage_sequence: 20
    },
    %{
      chapter_code: "12C20",
      chapter_name: "Surface Chemistry",
      grade: 12,
      subject: "Chemistry",
      exam_track: "neet",
      is_in_syllabus: false,
      prescribed_minutes: 0,
      coverage_sequence: 20
    },
    %{
      chapter_code: "12C21",
      chapter_name: "Metallurgy",
      grade: 12,
      subject: "Chemistry",
      exam_track: "jee_main",
      is_in_syllabus: false,
      prescribed_minutes: 0,
      coverage_sequence: 21
    },
    %{
      chapter_code: "12C21",
      chapter_name: "Metallurgy",
      grade: 12,
      subject: "Chemistry",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 660,
      coverage_sequence: 21
    },
    %{
      chapter_code: "12C21",
      chapter_name: "Metallurgy",
      grade: 12,
      subject: "Chemistry",
      exam_track: "neet",
      is_in_syllabus: false,
      prescribed_minutes: 0,
      coverage_sequence: 21
    },
    %{
      chapter_code: "12C22",
      chapter_name: "The p-Block Elements",
      grade: 12,
      subject: "Chemistry",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 840,
      coverage_sequence: 22
    },
    %{
      chapter_code: "12C22",
      chapter_name: "The p-Block Elements",
      grade: 12,
      subject: "Chemistry",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 2340,
      coverage_sequence: 22
    },
    %{
      chapter_code: "12C22",
      chapter_name: "The p-Block Elements",
      grade: 12,
      subject: "Chemistry",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 840,
      coverage_sequence: 22
    },
    %{
      chapter_code: "12C23",
      chapter_name: "The d and f-Block Elements",
      grade: 12,
      subject: "Chemistry",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 720,
      coverage_sequence: 23
    },
    %{
      chapter_code: "12C23",
      chapter_name: "The d and f-Block Elements",
      grade: 12,
      subject: "Chemistry",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 840,
      coverage_sequence: 23
    },
    %{
      chapter_code: "12C23",
      chapter_name: "The d and f-Block Elements",
      grade: 12,
      subject: "Chemistry",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 720,
      coverage_sequence: 23
    },
    %{
      chapter_code: "12C24",
      chapter_name: "Coordination Compounds",
      grade: 12,
      subject: "Chemistry",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 1020,
      coverage_sequence: 24
    },
    %{
      chapter_code: "12C24",
      chapter_name: "Coordination Compounds",
      grade: 12,
      subject: "Chemistry",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1320,
      coverage_sequence: 24
    },
    %{
      chapter_code: "12C24",
      chapter_name: "Coordination Compounds",
      grade: 12,
      subject: "Chemistry",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 1020,
      coverage_sequence: 24
    },
    %{
      chapter_code: "12C25",
      chapter_name: "Haloalkanes and Haloarenes",
      grade: 12,
      subject: "Chemistry",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 780,
      coverage_sequence: 25
    },
    %{
      chapter_code: "12C25",
      chapter_name: "Haloalkanes and Haloarenes",
      grade: 12,
      subject: "Chemistry",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 900,
      coverage_sequence: 25
    },
    %{
      chapter_code: "12C25",
      chapter_name: "Haloalkanes and Haloarenes",
      grade: 12,
      subject: "Chemistry",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 780,
      coverage_sequence: 25
    },
    %{
      chapter_code: "12C26",
      chapter_name: "Alcohols, Phenols and Ethers",
      grade: 12,
      subject: "Chemistry",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 840,
      coverage_sequence: 26
    },
    %{
      chapter_code: "12C26",
      chapter_name: "Alcohols, Phenols and Ethers",
      grade: 12,
      subject: "Chemistry",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1080,
      coverage_sequence: 26
    },
    %{
      chapter_code: "12C26",
      chapter_name: "Alcohols, Phenols and Ethers",
      grade: 12,
      subject: "Chemistry",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 840,
      coverage_sequence: 26
    },
    %{
      chapter_code: "12C27",
      chapter_name: "Aldehydes, Ketones and Carboxylic Acids",
      grade: 12,
      subject: "Chemistry",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 1080,
      coverage_sequence: 27
    },
    %{
      chapter_code: "12C27",
      chapter_name: "Aldehydes, Ketones and Carboxylic Acids",
      grade: 12,
      subject: "Chemistry",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1320,
      coverage_sequence: 27
    },
    %{
      chapter_code: "12C27",
      chapter_name: "Aldehydes, Ketones and Carboxylic Acids",
      grade: 12,
      subject: "Chemistry",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 1080,
      coverage_sequence: 27
    },
    %{
      chapter_code: "12C28",
      chapter_name: "Amines",
      grade: 12,
      subject: "Chemistry",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 660,
      coverage_sequence: 28
    },
    %{
      chapter_code: "12C28",
      chapter_name: "Amines",
      grade: 12,
      subject: "Chemistry",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 900,
      coverage_sequence: 28
    },
    %{
      chapter_code: "12C28",
      chapter_name: "Amines",
      grade: 12,
      subject: "Chemistry",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 660,
      coverage_sequence: 28
    },
    %{
      chapter_code: "12C29",
      chapter_name: "Biomolecules",
      grade: 12,
      subject: "Chemistry",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 360,
      coverage_sequence: 29
    },
    %{
      chapter_code: "12C29",
      chapter_name: "Biomolecules",
      grade: 12,
      subject: "Chemistry",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 480,
      coverage_sequence: 29
    },
    %{
      chapter_code: "12C29",
      chapter_name: "Biomolecules",
      grade: 12,
      subject: "Chemistry",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 360,
      coverage_sequence: 29
    },
    %{
      chapter_code: "12C30",
      chapter_name: "Polymers",
      grade: 12,
      subject: "Chemistry",
      exam_track: "jee_main",
      is_in_syllabus: false,
      prescribed_minutes: 0,
      coverage_sequence: 30
    },
    %{
      chapter_code: "12C30",
      chapter_name: "Polymers",
      grade: 12,
      subject: "Chemistry",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 480,
      coverage_sequence: 30
    },
    %{
      chapter_code: "12C30",
      chapter_name: "Polymers",
      grade: 12,
      subject: "Chemistry",
      exam_track: "neet",
      is_in_syllabus: false,
      prescribed_minutes: 0,
      coverage_sequence: 30
    },
    %{
      chapter_code: "12C31",
      chapter_name: "Chemistry in Everyday Lives",
      grade: 12,
      subject: "Chemistry",
      exam_track: "jee_main",
      is_in_syllabus: false,
      prescribed_minutes: 0,
      coverage_sequence: 31
    },
    %{
      chapter_code: "12C31",
      chapter_name: "Chemistry in Everyday Lives",
      grade: 12,
      subject: "Chemistry",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 300,
      coverage_sequence: 31
    },
    %{
      chapter_code: "12C31",
      chapter_name: "Chemistry in Everyday Lives",
      grade: 12,
      subject: "Chemistry",
      exam_track: "neet",
      is_in_syllabus: false,
      prescribed_minutes: 0,
      coverage_sequence: 31
    },
    %{
      chapter_code: "12C32",
      chapter_name: "Principles Related to Practical Chemistry",
      grade: 12,
      subject: "Chemistry",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 720,
      coverage_sequence: 32
    },
    %{
      chapter_code: "12C32",
      chapter_name: "Principles Related to Practical Chemistry",
      grade: 12,
      subject: "Chemistry",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 960,
      coverage_sequence: 32
    },
    %{
      chapter_code: "12C32",
      chapter_name: "Principles Related to Practical Chemistry",
      grade: 12,
      subject: "Chemistry",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 720,
      coverage_sequence: 32
    },
    %{
      chapter_code: "11M1",
      chapter_name: "Fundamentals of Mathematics",
      grade: 11,
      subject: "Maths",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 540,
      coverage_sequence: 1
    },
    %{
      chapter_code: "11M1",
      chapter_name: "Fundamentals of Mathematics",
      grade: 11,
      subject: "Maths",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 840,
      coverage_sequence: 1
    },
    %{
      chapter_code: "11M2",
      chapter_name: "Sets, Relations and Functions",
      grade: 11,
      subject: "Maths",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 720,
      coverage_sequence: 2
    },
    %{
      chapter_code: "11M2",
      chapter_name: "Sets, Relations and Functions",
      grade: 11,
      subject: "Maths",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1080,
      coverage_sequence: 2
    },
    %{
      chapter_code: "11M3",
      chapter_name: "Trigonometry",
      grade: 11,
      subject: "Maths",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 900,
      coverage_sequence: 3
    },
    %{
      chapter_code: "11M3",
      chapter_name: "Trigonometry",
      grade: 11,
      subject: "Maths",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1440,
      coverage_sequence: 3
    },
    %{
      chapter_code: "11M4",
      chapter_name: "Quadratic Equations",
      grade: 11,
      subject: "Maths",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 720,
      coverage_sequence: 4
    },
    %{
      chapter_code: "11M4",
      chapter_name: "Quadratic Equations",
      grade: 11,
      subject: "Maths",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1080,
      coverage_sequence: 4
    },
    %{
      chapter_code: "11M5",
      chapter_name: "Complex Number",
      grade: 11,
      subject: "Maths",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 900,
      coverage_sequence: 5
    },
    %{
      chapter_code: "11M5",
      chapter_name: "Complex Number",
      grade: 11,
      subject: "Maths",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1800,
      coverage_sequence: 5
    },
    %{
      chapter_code: "11M6",
      chapter_name: "Sequence and Series",
      grade: 11,
      subject: "Maths",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 720,
      coverage_sequence: 6
    },
    %{
      chapter_code: "11M6",
      chapter_name: "Sequence and Series",
      grade: 11,
      subject: "Maths",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1440,
      coverage_sequence: 6
    },
    %{
      chapter_code: "11M7",
      chapter_name: "Permutation and Combination",
      grade: 11,
      subject: "Maths",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 840,
      coverage_sequence: 7
    },
    %{
      chapter_code: "11M7",
      chapter_name: "Permutation and Combination",
      grade: 11,
      subject: "Maths",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1320,
      coverage_sequence: 7
    },
    %{
      chapter_code: "11M8",
      chapter_name: "Binomial Theorem",
      grade: 11,
      subject: "Maths",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 720,
      coverage_sequence: 8
    },
    %{
      chapter_code: "11M8",
      chapter_name: "Binomial Theorem",
      grade: 11,
      subject: "Maths",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1200,
      coverage_sequence: 8
    },
    %{
      chapter_code: "11M9",
      chapter_name: "Straight Lines",
      grade: 11,
      subject: "Maths",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 900,
      coverage_sequence: 9
    },
    %{
      chapter_code: "11M9",
      chapter_name: "Straight Lines",
      grade: 11,
      subject: "Maths",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1440,
      coverage_sequence: 9
    },
    %{
      chapter_code: "11M10",
      chapter_name: "Circle",
      grade: 11,
      subject: "Maths",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 900,
      coverage_sequence: 10
    },
    %{
      chapter_code: "11M10",
      chapter_name: "Circle",
      grade: 11,
      subject: "Maths",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1440,
      coverage_sequence: 10
    },
    %{
      chapter_code: "11M11",
      chapter_name: "Conic Sections",
      grade: 11,
      subject: "Maths",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 1080,
      coverage_sequence: 11
    },
    %{
      chapter_code: "11M11",
      chapter_name: "Conic Sections",
      grade: 11,
      subject: "Maths",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1800,
      coverage_sequence: 11
    },
    %{
      chapter_code: "11M12",
      chapter_name: "Statistics",
      grade: 11,
      subject: "Maths",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 480,
      coverage_sequence: 12
    },
    %{
      chapter_code: "11M12",
      chapter_name: "Statistics",
      grade: 11,
      subject: "Maths",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 720,
      coverage_sequence: 12
    },
    %{
      chapter_code: "12M13",
      chapter_name: "Functions",
      grade: 12,
      subject: "Maths",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 840,
      coverage_sequence: 13
    },
    %{
      chapter_code: "12M13",
      chapter_name: "Functions",
      grade: 12,
      subject: "Maths",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1200,
      coverage_sequence: 13
    },
    %{
      chapter_code: "12M14",
      chapter_name: "Inverse Trigonometric Functions",
      grade: 12,
      subject: "Maths",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 600,
      coverage_sequence: 14
    },
    %{
      chapter_code: "12M14",
      chapter_name: "Inverse Trigonometric Functions",
      grade: 12,
      subject: "Maths",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 960,
      coverage_sequence: 14
    },
    %{
      chapter_code: "12M15",
      chapter_name: "Matrices and Determinant",
      grade: 12,
      subject: "Maths",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 960,
      coverage_sequence: 15
    },
    %{
      chapter_code: "12M15",
      chapter_name: "Matrices and Determinant",
      grade: 12,
      subject: "Maths",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1320,
      coverage_sequence: 15
    },
    %{
      chapter_code: "12M16",
      chapter_name: "Limits",
      grade: 12,
      subject: "Maths",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 720,
      coverage_sequence: 16
    },
    %{
      chapter_code: "12M16",
      chapter_name: "Limits",
      grade: 12,
      subject: "Maths",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1080,
      coverage_sequence: 16
    },
    %{
      chapter_code: "12M17",
      chapter_name: "Continuity and Differentiability",
      grade: 12,
      subject: "Maths",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 840,
      coverage_sequence: 17
    },
    %{
      chapter_code: "12M17",
      chapter_name: "Continuity and Differentiability",
      grade: 12,
      subject: "Maths",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1200,
      coverage_sequence: 17
    },
    %{
      chapter_code: "12M18",
      chapter_name: "Application of Derivatives",
      grade: 12,
      subject: "Maths",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 900,
      coverage_sequence: 18
    },
    %{
      chapter_code: "12M18",
      chapter_name: "Application of Derivatives",
      grade: 12,
      subject: "Maths",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1320,
      coverage_sequence: 18
    },
    %{
      chapter_code: "12M19",
      chapter_name: "Indefinite Integration",
      grade: 12,
      subject: "Maths",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 960,
      coverage_sequence: 19
    },
    %{
      chapter_code: "12M19",
      chapter_name: "Indefinite Integration",
      grade: 12,
      subject: "Maths",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1440,
      coverage_sequence: 19
    },
    %{
      chapter_code: "12M20",
      chapter_name: "Definite Integration and AUC",
      grade: 12,
      subject: "Maths",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 1080,
      coverage_sequence: 20
    },
    %{
      chapter_code: "12M20",
      chapter_name: "Definite Integration and AUC",
      grade: 12,
      subject: "Maths",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1680,
      coverage_sequence: 20
    },
    %{
      chapter_code: "12M21",
      chapter_name: "Differential Equations",
      grade: 12,
      subject: "Maths",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 600,
      coverage_sequence: 21
    },
    %{
      chapter_code: "12M21",
      chapter_name: "Differential Equations",
      grade: 12,
      subject: "Maths",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 900,
      coverage_sequence: 21
    },
    %{
      chapter_code: "12M22",
      chapter_name: "Vector Algebra",
      grade: 12,
      subject: "Maths",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 720,
      coverage_sequence: 22
    },
    %{
      chapter_code: "12M22",
      chapter_name: "Vector Algebra",
      grade: 12,
      subject: "Maths",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1080,
      coverage_sequence: 22
    },
    %{
      chapter_code: "12M23",
      chapter_name: "Three Dimensional Geometry",
      grade: 12,
      subject: "Maths",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 720,
      coverage_sequence: 23
    },
    %{
      chapter_code: "12M23",
      chapter_name: "Three Dimensional Geometry",
      grade: 12,
      subject: "Maths",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1200,
      coverage_sequence: 23
    },
    %{
      chapter_code: "12M24",
      chapter_name: "Probability",
      grade: 12,
      subject: "Maths",
      exam_track: "jee_main",
      is_in_syllabus: true,
      prescribed_minutes: 840,
      coverage_sequence: 24
    },
    %{
      chapter_code: "12M24",
      chapter_name: "Probability",
      grade: 12,
      subject: "Maths",
      exam_track: "jee_advanced",
      is_in_syllabus: true,
      prescribed_minutes: 1200,
      coverage_sequence: 24
    },
    %{
      chapter_code: "12M25",
      chapter_name: "Linear Programming Problem",
      grade: 12,
      subject: "Maths",
      exam_track: "jee_main",
      is_in_syllabus: false,
      prescribed_minutes: 0,
      coverage_sequence: 25
    },
    %{
      chapter_code: "12M25",
      chapter_name: "Linear Programming Problem",
      grade: 12,
      subject: "Maths",
      exam_track: "jee_advanced",
      is_in_syllabus: false,
      prescribed_minutes: 0,
      coverage_sequence: 25
    },
    %{
      chapter_code: "12M26",
      chapter_name: "Mathematical Reasoning",
      grade: 12,
      subject: "Maths",
      exam_track: "jee_main",
      is_in_syllabus: false,
      prescribed_minutes: 0,
      coverage_sequence: 26
    },
    %{
      chapter_code: "12M26",
      chapter_name: "Mathematical Reasoning",
      grade: 12,
      subject: "Maths",
      exam_track: "jee_advanced",
      is_in_syllabus: false,
      prescribed_minutes: 0,
      coverage_sequence: 26
    },
    %{
      chapter_code: "12M27",
      chapter_name: "Solution of Triangle",
      grade: 12,
      subject: "Maths",
      exam_track: "jee_main",
      is_in_syllabus: false,
      prescribed_minutes: 0,
      coverage_sequence: 27
    },
    %{
      chapter_code: "12M27",
      chapter_name: "Solution of Triangle",
      grade: 12,
      subject: "Maths",
      exam_track: "jee_advanced",
      is_in_syllabus: false,
      prescribed_minutes: 0,
      coverage_sequence: 27
    },
    %{
      chapter_code: "12M28",
      chapter_name: "Hight and Distance",
      grade: 12,
      subject: "Maths",
      exam_track: "jee_main",
      is_in_syllabus: false,
      prescribed_minutes: 0,
      coverage_sequence: 28
    },
    %{
      chapter_code: "12M28",
      chapter_name: "Hight and Distance",
      grade: 12,
      subject: "Maths",
      exam_track: "jee_advanced",
      is_in_syllabus: false,
      prescribed_minutes: 0,
      coverage_sequence: 28
    },
    %{
      chapter_code: "11B1",
      chapter_name: "The Living World",
      grade: 11,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 240,
      coverage_sequence: 1
    },
    %{
      chapter_code: "11B2",
      chapter_name: "Biological Classification",
      grade: 11,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 480,
      coverage_sequence: 2
    },
    %{
      chapter_code: "11B3",
      chapter_name: "Plant Kingdom",
      grade: 11,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 600,
      coverage_sequence: 3
    },
    %{
      chapter_code: "11B4",
      chapter_name: "Animal Kingdom",
      grade: 11,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 600,
      coverage_sequence: 4
    },
    %{
      chapter_code: "11B5",
      chapter_name: "Morphology of Flowering Plants",
      grade: 11,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 720,
      coverage_sequence: 5
    },
    %{
      chapter_code: "11B6",
      chapter_name: "Anatomy of Flowering Plants",
      grade: 11,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 480,
      coverage_sequence: 6
    },
    %{
      chapter_code: "11B7",
      chapter_name: "Structural Organisation in Animals",
      grade: 11,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 300,
      coverage_sequence: 7
    },
    %{
      chapter_code: "11B8",
      chapter_name: "Cell: The Unit of Life",
      grade: 11,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 900,
      coverage_sequence: 8
    },
    %{
      chapter_code: "11B9",
      chapter_name: "Biomolecules",
      grade: 11,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 960,
      coverage_sequence: 9
    },
    %{
      chapter_code: "11B10",
      chapter_name: "Cell Cycle and Cell Division",
      grade: 11,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 600,
      coverage_sequence: 10
    },
    %{
      chapter_code: "11B11",
      chapter_name: "Transport in Plants",
      grade: 11,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: false,
      prescribed_minutes: 0,
      coverage_sequence: 11
    },
    %{
      chapter_code: "11B12",
      chapter_name: "Mineral Nutrition",
      grade: 11,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: false,
      prescribed_minutes: 0,
      coverage_sequence: 12
    },
    %{
      chapter_code: "11B13",
      chapter_name: "Photosynthesis in Higher Plants",
      grade: 11,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 900,
      coverage_sequence: 13
    },
    %{
      chapter_code: "11B14",
      chapter_name: "Respiration in Plants",
      grade: 11,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 720,
      coverage_sequence: 14
    },
    %{
      chapter_code: "11B15",
      chapter_name: "Plant Growth and Development",
      grade: 11,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 600,
      coverage_sequence: 15
    },
    %{
      chapter_code: "11B16",
      chapter_name: "Digestion and Absorption",
      grade: 11,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: false,
      prescribed_minutes: 0,
      coverage_sequence: 16
    },
    %{
      chapter_code: "11B17",
      chapter_name: "Breathing and Exchange of Gases",
      grade: 11,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 900,
      coverage_sequence: 17
    },
    %{
      chapter_code: "11B18",
      chapter_name: "Body Fluids and Circulation",
      grade: 11,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 720,
      coverage_sequence: 18
    },
    %{
      chapter_code: "11B19",
      chapter_name: "Excretory Products and their Elimination",
      grade: 11,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 900,
      coverage_sequence: 19
    },
    %{
      chapter_code: "11B20",
      chapter_name: "Locomotion and Movement",
      grade: 11,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 720,
      coverage_sequence: 20
    },
    %{
      chapter_code: "11B21",
      chapter_name: "Neural Control and Coordination",
      grade: 11,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 600,
      coverage_sequence: 21
    },
    %{
      chapter_code: "11B22",
      chapter_name: "Chemical Coordination and Integration",
      grade: 11,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 1200,
      coverage_sequence: 22
    },
    %{
      chapter_code: "12B23",
      chapter_name: "Reproduction in Organisms",
      grade: 12,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: false,
      prescribed_minutes: 0,
      coverage_sequence: 23
    },
    %{
      chapter_code: "12B24",
      chapter_name: "Sexual Reproduction in Flowering Plants",
      grade: 12,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 1080,
      coverage_sequence: 24
    },
    %{
      chapter_code: "12B25",
      chapter_name: "Human Reproduction",
      grade: 12,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 1080,
      coverage_sequence: 25
    },
    %{
      chapter_code: "12B26",
      chapter_name: "Reproductive Health",
      grade: 12,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 600,
      coverage_sequence: 26
    },
    %{
      chapter_code: "12B27",
      chapter_name: "Principles of Inheritance and Variation",
      grade: 12,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 1200,
      coverage_sequence: 27
    },
    %{
      chapter_code: "12B28",
      chapter_name: "Molecular Basis of Inheritance",
      grade: 12,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 1500,
      coverage_sequence: 28
    },
    %{
      chapter_code: "12B29",
      chapter_name: "Evolution",
      grade: 12,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 900,
      coverage_sequence: 29
    },
    %{
      chapter_code: "12B30",
      chapter_name: "Human Health and Diseases",
      grade: 12,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 1080,
      coverage_sequence: 30
    },
    %{
      chapter_code: "12B31",
      chapter_name: "Strategies for Enhancement in Food Production",
      grade: 12,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: false,
      prescribed_minutes: 0,
      coverage_sequence: 31
    },
    %{
      chapter_code: "12B32",
      chapter_name: "Microbes in Human Welfare",
      grade: 12,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 600,
      coverage_sequence: 32
    },
    %{
      chapter_code: "12B33",
      chapter_name: "Biotechnology - Principles and Processes",
      grade: 12,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 1080,
      coverage_sequence: 33
    },
    %{
      chapter_code: "12B34",
      chapter_name: "Biotechnology and Its Application",
      grade: 12,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 720,
      coverage_sequence: 34
    },
    %{
      chapter_code: "12B35",
      chapter_name: "Organisms and Populations",
      grade: 12,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 600,
      coverage_sequence: 35
    },
    %{
      chapter_code: "12B36",
      chapter_name: "Ecosystem",
      grade: 12,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 600,
      coverage_sequence: 36
    },
    %{
      chapter_code: "12B37",
      chapter_name: "Biodiversity and Its Conservation",
      grade: 12,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: true,
      prescribed_minutes: 600,
      coverage_sequence: 37
    },
    %{
      chapter_code: "12B38",
      chapter_name: "Environmental Issues",
      grade: 12,
      subject: "Biology",
      exam_track: "neet",
      is_in_syllabus: false,
      prescribed_minutes: 0,
      coverage_sequence: 38
    }
  ]

  def version, do: @version
  def rows, do: @rows
  def expected_counts, do: @expected_counts

  def counts_by_subject do
    @rows
    |> Enum.group_by(& &1.subject)
    |> Map.new(fn {subject, rows} -> {subject, length(rows)} end)
  end
end
