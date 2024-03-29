Feature: End to end tests
  These scenarios use a JSON file generated by sous_vide from the `e2e` kitchen suite and for the
  most part are located in `cookbooks/sous_vide/recipes/e2e.rb`.

  Cucumber uses `tmp/sous-vide-report.json` file and it should be generated using
  `kitchen converge e2e` command.

  Background:
    Given I load SousVide report at "tmp/sous-vide-report.json"

  Scenario: events are captured immediately after sous_vide registration at compile-time
    # sous_vide can't see events before it's registration.
    # It will also not report self. Although the handler receives the "resource_completed" event,
    # it did not get "resource_action_start" so the event is considered out-of-bound and is ignored.
    When I inspect event at position "0"
    Then current event "chef_resource_type" is "execute"
    And current event "chef_resource_name" is "compile-time immediately after register sous handler"
    And current event "chef_resource_execution_phase" is "compile"

  Scenario: compile-time resources are still captured in converge phase
    # This is a result of 2-phase chef-client execution model.
    When I inspect event "ruby_block[register sous handler]" at "converge" phase
    Then current event "chef_resource_status" is "skipped"
    When I inspect next event
    Then current event "chef_resource_type" is "execute"
    And current event "chef_resource_name" is "compile-time immediately after register sous handler"
    And current event "chef_resource_status" is "skipped"

  Scenario: diffs are not generated for skipped resources
    When I inspect event "service[skip-me-service]" at "converge" phase
    Then current event "chef_resource_diff" is ""

  # File diffs
  Scenario: file diff is captured when file is changed
    When I inspect event "file[/sous_vide/tmp/diff_test_changed.txt" at "converge" phase
    Then current event "chef_resource_diff" matches "file has been changed"

  Scenario: file diff is not captured when new file is created
    When I inspect event "file[/sous_vide/tmp/diff_test_new.txt" at "converge" phase
    Then current event "chef_resource_diff" is ""

  Scenario: file diff is not captured when file is up to date
    When I inspect event "file[/sous_vide/tmp/diff_test_up_to_date.txt" at "converge" phase
    Then current event "chef_resource_diff" is ""

  Scenario: file diff is suppressed for sensitive content
    When I inspect event "file[/sous_vide/tmp/diff_test_sensitive.txt" at "converge" phase
    Then current event "chef_resource_diff" is "suppressed sensitive resource"

  Scenario: file diff is captured for cookbook files
    When I inspect event "cookbook_file[/sous_vide/tmp/diff_test_cookbook_file.txt]" at "converge" phase
    Then current event "chef_resource_diff" matches "-Hello Sous, this cookbook file"

  Scenario: file diff is captured for templates
    When I inspect event "template[/sous_vide/tmp/diff_test_template.txt]" at "converge" phase
    Then current event "chef_resource_diff" matches "-Hello Sous, this template will change"

  # Package diffs
  Scenario: apt package diff is captured when a package is installed
    When I inspect event "apt_package[install sous-package v0.0.2]" at "converge" phase
    Then current event "chef_resource_diff" matches "Packages: sous-package"
    And current event "chef_resource_diff" matches "Current versions: none"
    And current event "chef_resource_diff" matches "Wanted versions: 0.0.2"
    And current event "chef_resource_status" is "updated"

  Scenario: apt package diff is captured when a package is downgraded
    When I inspect event "apt_package[install (downgrade) sous-package v0.0.1]" at "converge" phase
    Then current event "chef_resource_diff" matches "Packages: sous-package"
    And current event "chef_resource_diff" matches "Current versions: 0.0.2"
    And current event "chef_resource_diff" matches "Wanted versions: 0.0.1"
    And current event "chef_resource_status" is "updated"

  Scenario: apt package diff is captured when a package is upgraded to specific version
    When I inspect event "apt_package[install (upgrade) sous-package v0.0.2]" at "converge" phase
    Then current event "chef_resource_diff" matches "Packages: sous-package"
    And current event "chef_resource_diff" matches "Current versions: 0.0.1"
    And current event "chef_resource_diff" matches "Wanted versions: 0.0.2"
    And current event "chef_resource_status" is "updated"

  Scenario: apt package diff is captured when a package is removed
    When I inspect event "apt_package[remove sous-package]" at "converge" phase
    Then current event "chef_resource_diff" matches "Packages: sous-package"
    And current event "chef_resource_diff" matches "Current versions: 0.0.2"
    And current event "chef_resource_diff" matches "Wanted versions: none"
    And current event "chef_resource_status" is "updated"

  Scenario: apt package diff is captured when a package is upgraded to latest
    When I inspect event "apt_package[upgrade sous-package to latest]" at "converge" phase
    Then current event "chef_resource_diff" matches "Packages: sous-package"
    And current event "chef_resource_diff" matches "Current versions: none"
    And current event "chef_resource_diff" matches "Wanted versions: latest"
    And current event "chef_resource_status" is "updated"

  Scenario: apt package diff is captured when a package is up to date
    When I inspect event "apt_package[install sous-package v0.0.2 (up to date)]" at "converge" phase
    Then current event "chef_resource_diff" matches "Packages: sous-package"
    And current event "chef_resource_diff" matches "Current versions: 0.0.2"
    And current event "chef_resource_diff" matches "Wanted versions: 0.0.2"
    And current event "chef_resource_status" is "up-to-date"

  Scenario: apt package diff is captured when a package is locked
    When I inspect event "apt_package[lock sous-package]" at "converge" phase
    Then current event "chef_resource_diff" matches "Packages: sous-package"
    And current event "chef_resource_diff" matches "Current versions: 0.0.2"
    And current event "chef_resource_diff" matches "Wanted versions: 0.0.2"
    And current event "chef_resource_status" is "updated"

  Scenario: apt package diff is captured when a package is unlocked
    When I inspect event "apt_package[unlock sous-package]" at "converge" phase
    Then current event "chef_resource_diff" matches "Packages: sous-package"
    And current event "chef_resource_diff" matches "Current versions: 0.0.2"
    And current event "chef_resource_diff" matches "Wanted versions:  "

  Scenario: multi-package diff is captured for all packages
    When I inspect event "apt_package[install multiple packages]" at "converge" phase
    Then current event "chef_resource_diff" matches "Packages: sous-package, sous-package"
    And current event "chef_resource_diff" matches "Current versions: 0.0.2, 0.0.2"
    And current event "chef_resource_diff" matches "Wanted versions: any, any"

  Scenario: multi-package & multi-version diff is captured for all versions
    When I inspect event "apt_package[install multiple packages and versions]" at "converge" phase
    Then current event "chef_resource_diff" matches "Packages: sous-package, sous-package, sous-package"
    And current event "chef_resource_diff" matches "Current versions: 0.0.2, 0.0.2, 0.0.2"
    And current event "chef_resource_diff" matches "Wanted versions: 0.0.2, 0.0.2, any"

  Scenario: multi-package diff captures version "latest" when packages are upgraded
    When I inspect event "apt_package[upgrade multiple packages]" at "converge" phase
    Then current event "chef_resource_diff" matches "Packages: sous-package, sous-package"
    And current event "chef_resource_diff" matches "Current versions: 0.0.2, 0.0.2"
    And current event "chef_resource_diff" matches "Wanted versions: latest, latest"

  Scenario: multi-package diff captures version "none" when packages are removed
    When I inspect event "apt_package[remove multiple packages]" at "converge" phase
    Then current event "chef_resource_diff" matches "Packages: sous-faux-package, sous-faux-package"
    And current event "chef_resource_diff" matches "Current versions: none, none"
    And current event "chef_resource_diff" matches "Wanted versions: none, none"

  Scenario: gem package diff is captured
    When I inspect event "gem_package[addressable]" at "converge" phase
    Then current event "chef_resource_diff" matches "Packages: addressable"
    And current event "chef_resource_diff" matches "Current versions: 2."
    And current event "chef_resource_diff" matches "Wanted versions: any"

  Scenario: chef gem package diff is captured
    When I inspect event "chef_gem[addressable]" at "converge" phase
    Then current event "chef_resource_diff" matches "Packages: addressable"
    And current event "chef_resource_diff" matches "Current versions: 2."
    And current event "chef_resource_diff" matches "Wanted versions: any"

  Scenario: dpkg package diff is captured
    When I inspect event "dpkg_package[dpkg install sous-package]" at "converge" phase
    Then current event "chef_resource_diff" matches "Packages: sous-package"
    And current event "chef_resource_diff" matches "Current versions: 0.0.2"
    And current event "chef_resource_diff" matches "Wanted versions: any"

  # Service diffs
  Scenario: service diff is captured when a service is enabled
    When I inspect event "service[enable ntp]" at "converge" phase
    Then current event "chef_resource_diff" is "Enabled: no. Wants yes."
    And current event "chef_resource_status" is "updated"

  Scenario: service diff is captured when a service is started
    When I inspect event "service[start ntp]" at "converge" phase
    Then current event "chef_resource_diff" matches "Running: no. Wants yes."
    And current event "chef_resource_status" is "updated"

  Scenario: service diff is captured when a service is restarted
    When I inspect event "service[restart ntp]" at "converge" phase
    Then current event "chef_resource_diff" matches "Running: yes. Wants yes."
    And current event "chef_resource_status" is "updated"

  Scenario: service diff is captured when a service is stopped
    When I inspect event "service[stop ntp]" at "converge" phase
    Then current event "chef_resource_diff" matches "Running: yes. Wants no."
    And current event "chef_resource_status" is "updated"

  Scenario: service diff is captured when a service is disabled
    When I inspect event "service[disable ntp]" at "converge" phase
    Then current event "chef_resource_diff" matches "Enabled: yes. Wants no."
    And current event "chef_resource_status" is "updated"

  # User diffs
  Scenario: user diff is captured when new user is created
    When I inspect event "linux_user[create new sous-user]" at "converge" phase
    Then current event "chef_resource_diff" matches "Username: sous-user"
    And current event "chef_resource_diff" matches "User will be created."
    And current event "chef_resource_diff" matches "Chef attributes:"
    And current event "chef_resource_diff" matches "Comment:  Sous user comment"
    And current event "chef_resource_status" is "updated"

  Scenario: user diff is captured when a user is updated with :create action
    When I inspect event "linux_user[create (update) sous-user]" at "converge" phase
    Then current event "chef_resource_diff" matches "Username: sous-user"
    And current event "chef_resource_diff" matches "User will be updated."
    And current event "chef_resource_diff" matches "Current attributes:"
    And current event "chef_resource_diff" matches "Chef attributes:"
    And current event "chef_resource_diff" matches "Comment:  Updated user comment via create"
    And current event "chef_resource_status" is "updated"

  Scenario: user diff is captured when a user is updated with :modify action
    When I inspect event "linux_user[modify sous-user]" at "converge" phase
    Then current event "chef_resource_diff" matches "Username: sous-user"
    And current event "chef_resource_diff" matches "User will be updated."
    And current event "chef_resource_diff" matches "Current attributes:"
    And current event "chef_resource_diff" matches "Chef attributes:"
    And current event "chef_resource_diff" matches "Comment:  Modified user comment"
    And current event "chef_resource_status" is "updated"

  Scenario: user diff is captured when a user is updated with :manage action
    When I inspect event "linux_user[manage sous-user]" at "converge" phase
    Then current event "chef_resource_diff" matches "Username: sous-user"
    And current event "chef_resource_diff" matches "User will be updated."
    And current event "chef_resource_diff" matches "Current attributes:"
    And current event "chef_resource_diff" matches "Chef attributes:"
    And current event "chef_resource_diff" matches "Comment:  Managed user comment"
    And current event "chef_resource_status" is "updated"

  Scenario: user diff is captured when a user is locked
    When I inspect event "linux_user[lock sous-user]" at "converge" phase
    Then current event "chef_resource_diff" matches "Username: sous-user"
    And current event "chef_resource_diff" matches "User will be locked."
    And current event "chef_resource_diff" matches "Current attributes:"
    And current event "chef_resource_status" is "updated"

  Scenario: user diff is captured when a user is locked (up-to-date)
    When I inspect event "linux_user[lock (up-to-date) sous-user]" at "converge" phase
    Then current event "chef_resource_diff" matches "Username: sous-user"
    And current event "chef_resource_diff" matches "User is already locked."
    And current event "chef_resource_diff" matches "Current attributes:"
    And current event "chef_resource_status" is "up-to-date"

  Scenario: user diff is captured when a user is unlocked
    When I inspect event "linux_user[unlock sous-user]" at "converge" phase
    Then current event "chef_resource_diff" matches "Username: sous-user"
    And current event "chef_resource_diff" matches "User will be unlocked."
    And current event "chef_resource_diff" matches "Current attributes:"
    And current event "chef_resource_status" is "updated"

  Scenario: user diff is captured when a user is removed
    When I inspect event "linux_user[remove sous-user]" at "converge" phase
    Then current event "chef_resource_diff" matches "Username: sous-user"
    And current event "chef_resource_diff" matches "User will be deleted."
    And current event "chef_resource_diff" matches "Current attributes:"
    And current event "chef_resource_status" is "updated"

  Scenario: user diff is captured when :manage action is used on non-existing user
    When I inspect event "linux_user[manage non-existing sous-user]" at "converge" phase
    Then current event "chef_resource_diff" matches "Username: sous-user"
    And current event "chef_resource_diff" matches "User will not be updated."
    And current event "chef_resource_status" is "up-to-date"

  Scenario: user diff is captured when :remove action is used on non-existing user
    When I inspect event "linux_user[remove non-existing sous-user]" at "converge" phase
    Then current event "chef_resource_diff" matches "Username: sous-user"
    And current event "chef_resource_diff" matches "User does not exist."
    And current event "chef_resource_status" is "up-to-date"

  Scenario: user diff is not captured when it's skipped
    When I inspect event "linux_user[skip modify sous-user]" at "converge" phase
    Then current event "chef_resource_diff" is ""
    And current event "chef_resource_status" is "skipped"

  Scenario: user diff is not captured when action :nothing is used
    When I inspect event "linux_user[nothing sous-user]" at "converge" phase
    Then current event "chef_resource_diff" is ""
    And current event "chef_resource_status" is "skipped"

  # Nested resources
  Scenario: nested resources are ordered correctly
    # execute[e2e before nesting]
    # sous_vide_e2e_sous_nest[e2e sous nesting]
    # > execute[run_three action before]
    # > sous_vide_e2e_sous_nest[call run_two]
    # > > execute[run_two action before]
    # > > sous_vide_e2e_sous_nest[call run_two]
    # > > > execute[run_one action]
    # > > execute[run_two action after]
    # > execute[run_three action after]
    # execute[e2e after nesting]

    When I inspect event "execute[e2e before nesting]" at "converge" phase
    Then current event "chef_resource_nest_level" is "0"
    When I inspect next event
    Then current event "chef_resource_name" is "e2e sous nesting"
    Then current event "chef_resource_nest_level" is "0"
    When I inspect next event
    Then current event "chef_resource_name" is "run_three action before"
    And current event "chef_resource_nest_level" is "1"
    When I inspect next event
    Then current event "chef_resource_name" is "call run_two"
    And current event "chef_resource_nest_level" is "1"
    When I inspect next event
    Then current event "chef_resource_name" is "run_two action before"
    And current event "chef_resource_nest_level" is "2"
    When I inspect next event
    Then current event "chef_resource_name" is "call run_two"
    And current event "chef_resource_nest_level" is "2"
    When I inspect next event
    Then current event "chef_resource_name" is "run_one action"
    And current event "chef_resource_nest_level" is "3"
    When I inspect next event
    Then current event "chef_resource_name" is "run_two action after"
    And current event "chef_resource_nest_level" is "2"
    When I inspect next event
    Then current event "chef_resource_name" is "run_three action after"
    And current event "chef_resource_nest_level" is "1"
    When I inspect next event
    Then current event "chef_resource_name" is "e2e after nesting"
    And current event "chef_resource_nest_level" is "0"

  Scenario: sub-resources in nested resources capture diffs
    When I inspect event "file[e2e_sous_nest update file]" at "converge" phase
    Then current event "chef_resource_diff" matches "-old content"
    And current event "chef_resource_diff" matches "\+new content"
    And current event "chef_resource_status" is "updated"

  Scenario: parent resource status is "updated" when sub-resource is updated
    When I inspect event "file[e2e_sous_nest update file]" at "converge" phase
    Then current event "chef_resource_status" is "updated"
    When I inspect event "sous_vide_e2e_sous_nest[update file]" at "converge" phase
    Then current event "chef_resource_status" is "updated"

  Scenario: parent resource status is "up-to-date" when sub-resource is up-to-date
    When I inspect event "file[e2e_sous_nest up-to-date file]" at "converge" phase
    Then current event "chef_resource_status" is "up-to-date"
    When I inspect event "sous_vide_e2e_sous_nest[up-to-date file]" at "converge" phase
    Then current event "chef_resource_status" is "up-to-date"
