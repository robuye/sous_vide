Feature: Flamegraph
  Scenario: flat graph (no nesting)
    Given I have the following Flamegraph input events:
      | order | depth | type     | name          | action  | duration | status      | phase    |
      | 1     | 0     | template | /etc/hosts    | update  | 1        | up-to-date  | compile  |
      | 2     | 0     | template | /etc/rc.local | update  | 10       | updated     | converge |
      | 3     | 0     | execute  | /bin/true     | run     | 100      | updated     | converge |
      | 4     | 0     | execute  | /bin/false    | nothing | 0        | skipped     | converge |
    When I build a flamegraph
    Then I should have the following Flamegraph output:
      | line                                                  |
      | compile;1.template[/etc/hosts]#update(up-to-date) 1   |
      | converge;2.template[/etc/rc.local]#update(updated) 10 |
      | converge;3.execute[/bin/true]#run(updated) 100        |
      | converge;4.execute[/bin/false]#nothing(skipped) 1     |

  Scenario: nested graph, duration calculation
    # Notice duration in the output is different. Each node substracts duration of it's children
    # so the first node is 100 - 9 (node 2 minus node 3) = 91. Flamegraph expects non-cumulative
    # sample counts.
    #
    # Also last node ends up with duration 1, despite input being 0. Flamegraph would not render
    # nodes with zero samples so SousVide flamegraph output force 1 on zero or negative inputs.
    Given I have the following Flamegraph input events:
      | order | depth | type     | name          | action  | duration | status      | phase    |
      | 1     | 0     | template | /etc/hosts    | update  | 100      | up-to-date  | converge |
      | 2     | 1     | template | /etc/rc.local | update  | 10       | updated     | converge |
      | 3     | 2     | execute  | /bin/true     | run     | 1        | updated     | converge |
      | 4     | 1     | execute  | /bin/false    | nothing | 0        | skipped     | converge |
    When I build a flamegraph
    Then I should have the following Flamegraph output:
      | line                                                  |
      | converge;1.template[/etc/hosts]#update(up-to-date) 91 |
      | converge;1.template[/etc/hosts]#update(up-to-date);2.template[/etc/rc.local]#update(updated) 9 |
      | converge;1.template[/etc/hosts]#update(up-to-date);2.template[/etc/rc.local]#update(updated);3.execute[/bin/true]#run(updated) 1 |
      | converge;1.template[/etc/hosts]#update(up-to-date);4.execute[/bin/false]#nothing(skipped) 1 |


  Scenario: flat graph, special characters
    # Semicolon and space are control characters of flamegraph.pl and will be replaced with '_'
    Given I have the following Flamegraph input events:
      | order | depth | type | name        | action  | duration | status  | phase    |
      | 1     | 0     | log  | with spaces | update  | 1        | updated | compile  |
      | 2     | 0     | log  | semicolon;  | update  | 1        | updated | converge |
    When I build a flamegraph
    Then I should have the following Flamegraph output:
      | line                                         |
      | compile;1.log[with_spaces]#update(updated) 1 |
      | converge;2.log[semicolon_]#update(updated) 1 |

  Scenario: nested graph, color palette
    # Each individual event has a color. Parents are not included here. Color is determined by
    # status. If there are events with no color in the palette they will be assigned color
    # by flamegraph.pl script.
    Given I have the following Flamegraph input events:
      | order | depth | type     | name          | action  | duration | status      | phase    |
      | 1     | 0     | template | /etc/hosts    | update  | 1        | up-to-date  | compile  |
      | 2     | 0     | template | /etc/rc.local | update  | 10       | why-run     | converge |
      | 3     | 0     | execute  | /bin/true     | run     | 100      | updated     | converge |
      | 4     | 1     | execute  | /bin/false    | nothing | 0        | skipped     | converge |
    When I build a flamegraph
    Then I should have the following Flamegraph color palette output:
      | line                                                  |
      | compile->#B0DFE5                                      |
      | converge->#95C8D8                                     |
      | delayed->#588BAE                                      |
      | post-converge->#81D8D0                                |
      | 1.template[/etc/hosts]#update(up-to-date)->#66CC99    |
      | 2.template[/etc/rc.local]#update(why-run)->#6699FF    |
      | 3.execute[/bin/true]#run(updated)->#FFDC00            |
      | 4.execute[/bin/false]#nothing(skipped)->#DDDDDD       |
