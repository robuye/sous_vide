Given("I load SousVide report at {string}") do |path|
  expect(File).to exist(path)

  @sous_vide_report ||= JSON.parse(File.read(path)).sort_by do |hash|
    hash["chef_resource_order"]
  end
end

When("I inspect event {string} at {string} phase") do |event_name, phase|
  @current_event = @sous_vide_report.find do |event|
    event["chef_resource"].start_with?(event_name) &&
      event["chef_resource_execution_phase"] == phase
  end

  if @current_event.nil?
    fail "#{event_name} in #{phase} phase not found in #{@sous_vide_report.size} events."
  end
end

When("I inspect event at position {string}") do |position|
  @current_event = @sous_vide_report[position.to_i]
end

When("I inspect next event") do
  offset = @current_event["chef_resource_order"].to_i
  @current_event = @sous_vide_report[offset]
end

Then("current event {string} is {string}") do |property, expected_value|
  expect(@current_event[property].to_s).to eq(expected_value)
end

Then("current event {string} matches {string}") do |property, expected_value|
  expect(@current_event[property]).to match(expected_value)
end
