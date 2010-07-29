Feature: Setup a Cocoa app with choctop
  In order to reduce cost of using Sparkle to generate appcasts
  As a Cocoa developer or Cocoa application deployer
  I want a generator to install rake tasks that make using Sparkle easy-peasy
  
  Scenario: Install choctop into an app that has no existing Rakefile
    Given a Cocoa app that does not have an existing Rakefile
    When I run local executable "install_choctop" with arguments "."
    And Rakefile wired to use development code instead of installed RubyGem
    Then file "Rakefile" is created
    And I should see /rake build/
    And I should see /rake upload/
  
  Scenario: Run "install_choctop" without arguments shows an error
    Given a Cocoa app that does not have an existing Rakefile
    When I run local executable "install_choctop" with arguments ""
    Then I should see /USAGE: install_choctop path/to/project/
  
  Scenario: Install choctop and generate a release_notes file
    Given a Cocoa app that does not have an existing Rakefile
    When I run local executable "install_choctop" with arguments "."
    Then file "release_notes.txt" is created
    And file "release_notes.txt" contents does match /Initial release/
  
  Scenario: Install into a tmbundle
    Given a TextMate bundle project "MyBundle"
    When I run local executable "install_choctop" with arguments ". --textmate"
    Then file "Rakefile" is created
    Then file "release_notes.txt" is not created
    When I invoke task "rake dmg"
    And dmg "appcast/build/MyBundle.tmbundle.dmg" is mounted as "MyBundle.tmbundle"
    And file "MyBundle.tmbundle" in mounted volume is created
    And file "Applications" in mounted volume is not created
  
  