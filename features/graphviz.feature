Feature: Graphviz
  Scenario: simple graph without nesting
    # node_1
    # node_2
    # node_3
    # node_4
    Given I have the following Graphviz input events:
      | order | depth |
      | 1     | 0     |
      | 2     | 0     |
      | 3     | 0     |
      | 4     | 0     |
    When I build a Graphviz graph
    Then I should have the following Graphviz output:
      | edge                |
      | RUN_START -> node_1 |
      | node_1 -> node_2    |
      | node_2 -> node_3    |
      | node_3 -> node_4    |
      | node_4 -> RUN_END   |

  Scenario: graph with 1-level nesting
    # node_1
    #  node_2
    #  node_3
    # node_4
    Given I have the following Graphviz input events:
      | order | depth |
      | 1     | 0     |
      | 2     | 1     |
      | 3     | 1     |
      | 4     | 0     |
    When I build a Graphviz graph
    Then I should have the following Graphviz output:
      | edge                                                            |
      | RUN_START -> node_1                                             |
      | node_1 -> node_2 [dir=back, style=dashed, lhead=cluster_node_1] |
      | node_2 -> node_3                                                |
      | node_3 -> node_4 [style=invis]                                  |
      | node_4 -> RUN_END                                               |

  Scenario: graph with 2-level nesting
    # node_1
    #  node_2
    #   node_3
    #   node_4
    # node_5
    Given I have the following Graphviz input events:
      | order | depth |
      | 1     | 0     |
      | 2     | 1     |
      | 3     | 2     |
      | 4     | 2     |
      | 5     | 0     |
    When I build a Graphviz graph
    Then I should have the following Graphviz output:
      | edge                                                            |
      | RUN_START -> node_1                                             |
      | node_1 -> node_2 [dir=back, style=dashed, lhead=cluster_node_1] |
      | node_2 -> node_3 [dir=back, style=dashed, lhead=cluster_node_2] |
      | node_3 -> node_4                                                |
      | node_4 -> node_5 [style=invis]                                  |
      | node_1 -> node_5                                                |
      | node_5 -> RUN_END                                               |

  Scenario: graph with 3-level nesting
    # node_1
    #  node_2
    #   node_3
    #    node_4
    # node_5
    Given I have the following Graphviz input events:
      | order | depth |
      | 1     | 0     |
      | 2     | 1     |
      | 3     | 2     |
      | 4     | 3     |
      | 5     | 0     |
    When I build a Graphviz graph
    Then I should have the following Graphviz output:
      | edge                                                            |
      | RUN_START -> node_1                                             |
      | node_1 -> node_2 [dir=back, style=dashed, lhead=cluster_node_1] |
      | node_2 -> node_3 [dir=back, style=dashed, lhead=cluster_node_2] |
      | node_3 -> node_4 [dir=back, style=dashed, lhead=cluster_node_3] |
      | node_4 -> node_5 [style=invis]                                  |
      | node_1 -> node_5                                                |
      | node_5 -> RUN_END                                               |


  Scenario: graph with 3-level nesting and multiple events at each level
    # node_1
    #  node_2
    #   node_3
    #    node_4
    #    node_5
    #   node_6
    #  node_7
    # node_8
    # node_9
    Given I have the following Graphviz input events:
      | order | depth |
      | 1     | 0     |
      | 2     | 1     |
      | 3     | 2     |
      | 4     | 3     |
      | 5     | 3     |
      | 6     | 2     |
      | 7     | 1     |
      | 8     | 0     |
      | 9     | 0     |
    When I build a Graphviz graph
    Then I should have the following Graphviz output:
      | edge                                                            |
      | RUN_START -> node_1                                             |
      | node_1 -> node_2 [dir=back, style=dashed, lhead=cluster_node_1] |
      | node_1 -> node_8                                                |
      | node_2 -> node_3 [dir=back, style=dashed, lhead=cluster_node_2] |
      | node_2 -> node_7                                                |
      | node_3 -> node_4 [dir=back, style=dashed, lhead=cluster_node_3] |
      | node_3 -> node_6                                                |
      | node_3 -> node_4 [dir=back, style=dashed, lhead=cluster_node_3] |
      | node_4 -> node_5                                                |
      | node_5 -> node_6 [style=invis]                                  |
      | node_6 -> node_7 [style=invis]                                  |
      | node_7 -> node_8 [style=invis]                                  |
      | node_8 -> node_9                                                |
      | node_9 -> RUN_END                                               |

  Scenario: graph with 3-level nesting where innermost event is followed by top-level
    # node_1
    #  node_2
    #   node_3
    #    node_4
    # node 5
    Given I have the following Graphviz input events:
      | order | depth |
      | 1     | 0     |
      | 2     | 1     |
      | 3     | 2     |
      | 4     | 3     |
      | 5     | 0     |
    When I build a Graphviz graph
    Then I should have the following Graphviz output:
      | edge                                                            |
      | RUN_START -> node_1                                             |
      | node_1 -> node_2 [dir=back, style=dashed, lhead=cluster_node_1] |
      | node_1 -> node_5                                                |
      | node_2 -> node_3 [dir=back, style=dashed, lhead=cluster_node_2] |
      | node_3 -> node_4 [dir=back, style=dashed, lhead=cluster_node_3] |
      | node_4 -> node_5 [style=invis]                                  |
      | node_5 -> RUN_END                                               |

  Scenario: graph with multiple deep nestings, ends with a nested node
    # node_1
    #  node_2
    #   node_3
    #   node_4
    #  node_5
    #  node_6
    #   node_7
    #    node_8
    Given I have the following Graphviz input events:
      | order | depth |
      | 1     | 0     |
      | 2     | 1     |
      | 3     | 2     |
      | 4     | 2     |
      | 5     | 1     |
      | 6     | 1     |
      | 7     | 2     |
      | 8     | 3     |
    When I build a Graphviz graph
    Then I should have the following Graphviz output:
      | edge                                                            |
      | RUN_START -> node_1                                             |
      | node_1 -> node_2 [dir=back, style=dashed, lhead=cluster_node_1] |
      | node_1 -> RUN_END                                               |
      | node_2 -> node_3 [dir=back, style=dashed, lhead=cluster_node_2] |
      | node_2 -> node_5                                                |
      | node_3 -> node_4                                                |
      | node_4 -> node_5 [style=invis]                                  |
      | node_5 -> node_6                                                |
      | node_6 -> node_7 [dir=back, style=dashed, lhead=cluster_node_6] |
      | node_7 -> node_8 [dir=back, style=dashed, lhead=cluster_node_7] |
      | node_8 -> RUN_END [style=invis]                                 |
