Given("I have the following Flamegraph input events:") do |table|
  table.map_column!(:depth)    {|value| Integer(value) }
  table.map_column!(:duration) {|value| Integer(value) }
  table.map_column!(:order)    {|value| Integer(value) }

  @graph_input = table.hashes.map do |attributes|
    node = SousVide::Outputs::Flamegraph::Node.new
    attributes.each do |(k,v)|
      node.public_send("#{k}=", v)
    end
    node
  end
end

When("I build a flamegraph") do
  flamegraph = SousVide::Outputs::Flamegraph::Graph.new
  @graph_input.each do |node|
    flamegraph.add_node(node)
  end
  @flamegraph = flamegraph.render.lines.map(&:chomp)
  @flamegraph_palette = flamegraph.palette.lines.map(&:chomp)
end

Then("I should have the following Flamegraph output:") do |table|
  table.rows.flatten.each do |line|
    expect(@flamegraph).to include(line)
  end
end

Then("I should have the following Flamegraph color palette output:") do |table|
  table.rows.flatten.each do |line|
    expect(@flamegraph_palette).to include(line)
  end
end
