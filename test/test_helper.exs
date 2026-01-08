# Start the application to ensure registries and languages are initialized
{:ok, _} = Application.ensure_all_started(:nasty)

ExUnit.start()
