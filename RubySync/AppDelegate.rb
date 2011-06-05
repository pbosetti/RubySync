#
#  AppDelegate.rb
#  RubySync
#
#  Created by Paolo Bosetti on 6/1/11.
#  Copyright 2011 Dipartimento di Ingegneria Meccanica e Strutturale. All rights reserved.
#
require "yaml"

resources_path = NSBundle.mainBundle.resourcePath.fileSystemRepresentation
require "#{resources_path}/rbackup"

class AppDelegate
  attr_accessor :window
  attr_accessor :yaml_area
  attr_accessor :config_selector
  attr_accessor :ready, :rsyncRunning
  attr_accessor :statusText

  @@user_defaults = NSUserDefaults.standardUserDefaults
  @@example = <<-EXAMPLE
test:
  source: ~/Desktop/Art
  destination: ~/Desktop/rsync
  exclude: 
    - Art/p4010.png
site:
  server:
    source: /Users/me/site
    destination: deploy@server:/var/www
    exclude:
      - .git
      - /site/config/database.yml
usb:
  documents:
    source: ~/Documents
    destination: /Volumes/USB Key
    exclude:
      - Software
      - Virtual Machines.localized
  pictures:
    source: ~/Pictures
    destination: /Volumes/USB Key
    include:
      - Favorites
  EXAMPLE
  
  def applicationDidFinishLaunching(a_notification)
    @yaml_area.setFont NSFont.fontWithName("Menlo", size:10)
    @rbackup = RBackup.new(false, nil)
    @config_selector.removeAllItems
    if @@user_defaults.objectForKey(:yaml_string)
        @yaml_area.insertText @@user_defaults.objectForKey(:yaml_string)
    end
    self.setReady false
    self.setRsyncRunning false
    self.setStatusText ""
  end
  
  def insertExample(sender)
    @yaml_area.insertText @@example
  end
  
  def validate(sender)
    case sender.state
    when NSOnState
      begin
        @rbackup.yaml = YAML.load(@yaml_area.textStorage.mutableString)
        sender.setTitle "Valid"
        self.setStatusText "Valid configuration. Select profile and click Rsync button."
        @rbackup.get_profiles
        @config_selector.addItemsWithTitles @rbackup.names
        @config_selector.selectItemAtIndex 0
        self.setReady true
      rescue
        self.setStatusText "Validation Error #{$!}"
        sender.setState NSOffState
      end
    when NSOffState
      @config_selector.removeAllItems
      self.setStatusText "Edit configuration, then click 'Validate!'"
      sender.setTitle "Validate!"
      self.setReady false
    end
  end
  
  def run(sender)
    puts "****click!"
    if rsyncRunning then
      self.setStatusText "rsync already running: wait for termination."
    else
      active_profile = @config_selector.titleOfSelectedItem
      @rbackup.args = active_profile
      @rbackup.profiles = nil
      self.setStatusText "Starting rsync..."
      self.setRsyncRunning true
      @rsync_thread = Thread.start(active_profile) do |p|
        closeButton = window.standardWindowButton(NSWindowCloseButton)
        closeButton.setEnabled false
        sleep 2
        @rbackup.run
        self.setStatusText "Profile #{p} successfully performed!"
        self.setRsyncRunning false
        closeButton.setEnabled true
      end
    end
  end
  
  def terminate(sender)
    @rsync_thread.kill if @rsync_thread
    self.setStatusText "Profile #{@rbackup.args} successfully performed!"
  end
  
  def applicationWillTerminate(a_notification)
    puts "Closing"
    @@user_defaults.setObject @yaml_area.textStorage.mutableString, :forKey => :yaml_string
    puts "Defaults saved"
    if @rsync_thread
      self.setStatusText "Waiting for rsync to terminate"
      @rsync_thread.join
    end
  end
  
  def applicationShouldTerminateAfterLastWindowClosed(application)
    true
  end
  
end

