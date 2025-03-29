if System.otp_release() >= "27" do
  config :logger,
    handle_otp_reports: true,
    handle_sasl_reports: true,
    metadata: %{
      request_id: true
    }
else
  config :logger,
    handle_otp_reports: true,
    handle_sasl_reports: true,
    metadata: [:request_id]
end