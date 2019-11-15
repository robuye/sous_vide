Given("I have the following input events:") do |table|
  @graph_input = table.hashes.map do |attributes|
    node = SousVide::Outputs::Graphviz::Node.new
    node.depth = attributes['depth'].to_i
    node.order = attributes['order']
    node
  end
end

When("I build a graph") do
  @graph = SousVide::Outputs::Graphviz::Graph.new
  @graph_input.each do |node|
    @graph.add_node(node)
  end
  @graph.build_edges!
end

Then("I should have the following edges:") do |table|
  table.rows.flatten.each do |edge|
    expect(@graph.edges).to include(edge)
  end
end
