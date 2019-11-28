Given("I have the following Graphviz input events:") do |table|
  table.map_column!(:depth) {|value| Integer(value) }
  table.map_column!(:order) {|value| Integer(value) }

  @graph_input = table.hashes.map do |attributes|
    node = SousVide::Outputs::Graphviz::Node.new
    attributes.each do |(k,v)|
      node.public_send("#{k}=", v)
    end
    node
  end
end

When("I build a Graphviz graph") do
  @graph = SousVide::Outputs::Graphviz::Graph.new
  @graph_input.each do |node|
    @graph.add_node(node)
  end
  @graph.build_edges!
end

Then("I should have the following Graphviz output:") do |table|
  table.rows.flatten.each do |edge|
    expect(@graph.edges).to include(edge)
  end
end
