alias Dbservice.Repo
alias Dbservice.FormSchemas.FormSchema

IO.puts("  → Seeding form schemas...")

form_schemas_data = [
  %{
    name: "Enable G11 G12 Profile Completion",
    attributes: %{
      "fields" => [
        %{
          "key" => "physically_handicapped",
          "type" => "dropdown",
          "label" => %{"en" => "Are you differently abled?", "hi" => "क्या आप दिव्यांग हैं?"},
          "options" => %{
            "en" => [%{"label" => "Yes", "value" => "Yes"}, %{"label" => "No", "value" => "No"}],
            "hi" => [%{"label" => "Yes", "value" => "Yes"}, %{"label" => "No", "value" => "No"}]
          },
          "helpText" => %{"en" => "", "hi" => ""},
          "required" => true
        },
        %{
          "key" => "phone",
          "type" => "phone",
          "label" => %{"en" => "Mobile Number", "hi" => "मोबाईल नंबर"},
          "options" => %{
            "en" => [%{"label" => "", "value" => ""}],
            "hi" => [%{"label" => "", "value" => ""}]
          },
          "helpText" => %{
            "en" => "You will receive calls regarding class, tests, test scores from Avanti in this number",
            "hi" => "आपको इस नंबर पर हमारी ओर से क्लास, टेस्ट और स्कोर के संबंध में कॉल प्राप्त होंगी"
          },
          "required" => true
        },
        %{
          "key" => "whatsapp_phone",
          "type" => "phone",
          "label" => %{"en" => "WhatsApp Number", "hi" => "व्हाट्सप्प नंबर"},
          "options" => %{
            "en" => [%{"label" => "", "value" => ""}],
            "hi" => [%{"label" => "", "value" => ""}]
          },
          "helpText" => %{
            "en" => "You will receive notifications, class and test links from Avanti in this number",
            "hi" => "आपको इस नंबर पर हमारी ओर से सूचनाएं, कक्षा और परीक्षण लिंक प्राप्त होंगे"
          },
          "required" => true
        },
        %{
          "key" => "email",
          "type" => "email",
          "label" => %{"en" => "Email ID", "hi" => "ईमेल आईडी"},
          "options" => %{
            "en" => [%{"label" => "", "value" => ""}],
            "hi" => [%{"label" => "", "value" => ""}]
          },
          "helpText" => %{"en" => "", "hi" => ""},
          "required" => false
        },
        %{
          "key" => "annual_family_income",
          "type" => "dropdown",
          "label" => %{"en" => "Annual Family Income", "hi" => "वार्षिक पारिवारिक आय"},
          "options" => %{
            "en" => [
              %{"label" => "Less than Rs. 120,000", "value" => "Less than Rs. 120,000"},
              %{"label" => "Rs. 120,000-240,000", "value" => "Rs. 120,000-240,000"},
              %{"label" => "Rs. 240,000-360,000", "value" => "Rs. 240,000-360,000"},
              %{"label" => "Rs. 360,000-480,000", "value" => "Rs. 360,000-480,000"},
              %{"label" => "Rs. 480,000-60,000", "value" => "Rs. 480,000-60,000"},
              %{"label" => "Rs. 60,000-720,000", "value" => "Rs. 60,000-720,000"},
              %{"label" => "Rs. 720,000-840,000", "value" => "Rs. 720,000-840,000"},
              %{"label" => "Rs. 840,000-1,080,000", "value" => "Rs. 840,000-1,080,000"},
              %{"label" => "Rs. 1,080,000-1,200,000", "value" => "Rs. 1,080,000-1,200,000"},
              %{"label" => "Rs. 1,200,000-1,320,000", "value" => "Rs. 1,200,000-1,320,000"},
              %{"label" => "More than Rs. 1,320,000", "value" => "More than Rs. 1,320,000"}
            ],
            "hi" => [
              %{"label" => "Less than Rs. 120,000", "value" => "Less than Rs. 120,000"},
              %{"label" => "Rs. 120,000-240,000", "value" => "Rs. 120,000-240,000"},
              %{"label" => "Rs. 240,000-360,000", "value" => "Rs. 240,000-360,000"},
              %{"label" => "Rs. 360,000-480,000", "value" => "Rs. 360,000-480,000"},
              %{"label" => "Rs. 480,000-60,000", "value" => "Rs. 480,000-60,000"},
              %{"label" => "Rs. 60,000-720,000", "value" => "Rs. 60,000-720,000"},
              %{"label" => "Rs. 720,000-840,000", "value" => "Rs. 720,000-840,000"},
              %{"label" => "Rs. 840,000-1,080,000", "value" => "Rs. 840,000-1,080,000"},
              %{"label" => "Rs. 1,080,000-1,200,000", "value" => "Rs. 1,080,000-1,200,000"},
              %{"label" => "Rs. 1,200,000-1,320,000", "value" => "Rs. 1,200,000-1,320,000"},
              %{"label" => "More than Rs. 1,320,000", "value" => "More than Rs. 1,320,000"}
            ]
          },
          "helpText" => %{"en" => "Enter your family income in a year", "hi" => ""},
          "required" => true
        },
        %{
          "key" => "board_stream",
          "type" => "dropdown",
          "label" => %{"en" => "Board Stream", "hi" => ""},
          "options" => %{
            "en" => [
              %{"label" => "PCM", "value" => "PCM"},
              %{"label" => "PCB", "value" => "PCB"},
              %{"label" => "PCMB", "value" => "PCMB"}
            ],
            "hi" => [%{"label" => "", "value" => "PCM"}]
          },
          "helpText" => %{"en" => "Select the subject you have taken in grade 11 & 12 CBSE\nP - Physics, C - Chemistry, M - Mathematics, B - Biology", "hi" => ""},
          "required" => true
        },
        %{
          "key" => "stream",
          "type" => "dropdown",
          "label" => %{"en" => "Select your stream", "hi" => ""},
          "options" => %{
            "en" => [
              %{"label" => "Engineering", "value" => "Engineering"},
              %{"label" => "Medical", "value" => "Medical"}
            ],
            "hi" => [%{"label" => "", "value" => "Engineering"}]
          },
          "helpText" => %{"en" => "", "hi" => ""},
          "required" => true
        },
        %{
          "key" => "planned_competitive_exams",
          "type" => "dropdown",
          "label" => %{"en" => "Select all the exams you are planning to give?", "hi" => "उन सभी परीक्षाओं का चयन करें जिन्हें आप देने की योजना बना रहे हैं?"},
          "options" => %{
            "en" => [
              %{"label" => "JEE", "value" => "JEE"},
              %{"label" => "NEET", "value" => "NEET"},
              %{"label" => "CUET", "value" => "CUET"},
              %{"label" => "KCET", "value" => "KCET"}
            ],
            "hi" => [
              %{"label" => "JEE", "value" => "JEE"},
              %{"label" => "NEET", "value" => "NEET"},
              %{"label" => "CUET", "value" => "CUET"},
              %{"label" => "KCET", "value" => "KCET"}
            ]
          },
          "helpText" => %{"en" => "You can select more than one exam ", "hi" => ""},
          "required" => true,
          "multipleSelect" => true
        }
      ]
    }
  }
]

form_schemas_created =
  for form_schema_attrs <- form_schemas_data do
    unless Repo.get_by(FormSchema, name: form_schema_attrs.name) do
      %FormSchema{}
      |> FormSchema.changeset(form_schema_attrs)
      |> Repo.insert!()
      1
    else
      0
    end
  end
  |> Enum.sum()

IO.puts("    ✅ Form schemas seeded (#{length(form_schemas_data)} total, #{form_schemas_created} new form schemas created)")
