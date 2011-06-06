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
  attr_accessor :ready, :rsyncRunning
  attr_accessor :window
  attr_accessor :yamlArea, :msgArea
  attr_accessor :configSelector
  attr_accessor :statusText
  attr_accessor :splitView

  @@user_defaults = NSUserDefaults.standardUserDefaults
  @@defaultFile = "#{ENV['HOME']}/.rbackup.yml"
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
    @yamlArea.setFont NSFont.fontWithName("Menlo", size:10)
    @msgArea.setFont NSFont.fontWithName("Menlo", size:10)
    @rbackup = RBackup.new(false, nil)
    @configSelector.removeAllItems
    if @@user_defaults.objectForKey(:yaml_string)
        @yamlArea.insertText @@user_defaults.objectForKey(:yaml_string)
    end
    self.setReady false
    self.setRsyncRunning false
    self.setStatusText ""
    @splitView.setAutosaveName "splitView"
  end
  
  def insertExample(sender)
    @splitView.setPosition @splitView.bounds.size.width, ofDividerAtIndex:0
    @yamlArea.insertText @@example
  end
  
  def saveYAML(sender)
    puts "Saving to #{@@defaultFile}"
    File.open(@@defaultFile, "w") {|f| f.print(@yamlArea.textStorage.mutableString)}
  end
  
  def validate(sender)
    case sender.state
    when NSOnState
      begin
        @rbackup.yaml = YAML.load(@yamlArea.textStorage.mutableString)
        sender.setTitle "Valid"
        self.setStatusText "Valid configuration. Select profile and click Rsync button."
        @rbackup.get_profiles
        @configSelector.addItemsWithTitles @rbackup.names
        @configSelector.selectItemAtIndex 0
        self.setReady true
      rescue
        self.setStatusText "Validation Error #{$!}"
        sender.setState NSOffState
      end
    when NSOffState
      @configSelector.removeAllItems
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
      active_profile = @configSelector.titleOfSelectedItem
      @rbackup.args = active_profile
      @rbackup.profiles = nil
      @rbackup.get_profiles
      self.setStatusText "Starting rsync..."
      self.setRsyncRunning true
      @rsync_thread = Thread.start(active_profile) do |p|
        @msgArea.insertText "Starting rsync with profile #{active_profile}\n"
        # @splitView.setPosition 0.0, ofDividerAtIndex:0
        closeButton = window.standardWindowButton(NSWindowCloseButton)
        closeButton.setEnabled false
        cmd_args = @rbackup.make_cmd(@rbackup.profiles[0])
        cmd = "rsync " + (cmd_args * ' ')
        @msgArea.insertText cmd.inspect
        @msgArea.insertText `#{cmd}`
        self.setStatusText "Profile #{p} successfully performed!"
        self.setRsyncRunning false
        closeButton.setEnabled true
        # @splitView.setPosition @splitView.bounds.size.width, ofDividerAtIndex:0
      end
    end
  end
  
  def terminate(sender)
    @rsync_thread.exit if @rsync_thread.alive?
    self.setStatusText "Profile #{@rbackup.args} currently is #{@rsync_thread.status.to_s}"
    self.setRsyncRunning false
    window.standardWindowButton(NSWindowCloseButton).setEnabled true
  end
  
  def applicationWillTerminate(a_notification)
    puts "Closing"
    @@user_defaults.setObject @yamlArea.textStorage.mutableString, :forKey => :yaml_string
    puts "Defaults saved"
    if @rsync_thread.alive?
      self.setStatusText "Waiting for rsync to terminate"
      @rsync_thread.join
    end
  end
  
  def applicationShouldTerminateAfterLastWindowClosed(application)
    true
  end
  
end

