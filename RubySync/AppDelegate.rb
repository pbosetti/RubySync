#
#  AppDelegate.rb
#  RubySync
#
#  Created by Paolo Bosetti on 6/1/11.
#  Copyright 2011 Dipartimento di Ingegneria Meccanica e Strutturale. All rights reserved.
#
require "yaml"

RESOURCES_PATH = NSBundle.mainBundle.resourcePath.fileSystemRepresentation
require "#{RESOURCES_PATH}/profileManager"

#(fold)
EXAMPLE = <<-EXAMPLE_STRING
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
    delete: truer
    include:
      - Favorites
EXAMPLE_STRING
#(end)  

# see http://ofps.oreilly.com/titles/9781449380373/_foundation.html

class Preferences < Hash
  def initialize
    @userDefaults = NSUserDefaults.standardUserDefaults
    self["rsyncOpts"] = (userDef("defaults") || {
      "update"   => false,
      "delete" => false,
      "dry"   => false
      })
    self["appMode"] = (userDef("appMode") || 1)
    self["yaml_string"] = (userDef("yaml_string") || EXAMPLE)
    self["lastSyncDate"] = (userDef("lastSyncDate") || "Unknown")
    self["lastSyncProfile"] = (userDef("lastSyncProfile") || "Unknown")
  end
  
  def save
    each do |key, value|
      setUserDef(key, value)
    end
  end
  
  def userDef(key)
    @userDefaults.objectForKey(key)
  end
  
  def setUserDef(key, value)
    @userDefaults.setObject value, forKey:key
  end
end

class AppDelegate < DockStatusManager
  attr_accessor :ready, :rsyncRunning
  attr_accessor :window, :mainMenu, :application, :quitMenuItem
  attr_accessor :yamlArea, :msgArea
  attr_accessor :configSelector
  attr_accessor :statusText
  attr_accessor :splitView
  attr_accessor :messageLog
  attr_accessor :systemMenu, :lastSyncMenuItem, :lastProfileMenuItem
  attr_accessor :prefs
  
  @@defaultFile = "#{ENV['HOME']}/.rbackup.yml"
  def awakeFromNib
    @prefs = Preferences.new
  end
  
  def applicationDidFinishLaunching(a_notification)
    @yamlArea.setFont NSFont.fontWithName("Menlo", size:10)
    @msgArea.setFont NSFont.fontWithName("Menlo", size:10)
    @profileManager = ProfileManager.new
    self.setDockStatus(prefs["appMode"] == 1)
    
    @configSelector.removeAllItems
    @yamlArea.insertText prefs["yaml_string"]
    self.setReady false
    self.setRsyncRunning false
    self.setStatusText ""
    @splitView.setAutosaveName "splitView"
    
    activateStatusMenu unless prefs["appMode"] == 1
    window.makeKeyAndOrderFront(self) if prefs["appMode"] == 1
    systemMenu.removeItem quitMenuItem if prefs["appMode"] == 1
    lastSyncDate = prefs["lastSyncDate"]
    lastSyncProfile = prefs["lastSyncProfile"]
    @lastSyncMenuItem.setTitle "Last Sync: #{lastSyncDate}"
    @lastProfileMenuItem.setTitle "Last Profile: #{lastSyncProfile}"
  end
  
  def activateStatusMenu
    image = NSImage.imageNamed("menuIcon_small.png")
    bar = NSStatusBar.systemStatusBar
    @menuBarItem = bar.statusItemWithLength NSVariableStatusItemLength
    @menuBarItem.setImage image
    @menuBarItem.setHighlightMode true
    @menuBarItem.setMenu systemMenu
  end
  
  def insertExample(sender)
    @splitView.setPosition @splitView.bounds.size.width, ofDividerAtIndex:0
    @yamlArea.insertText EXAMPLE_STRING
  end
  
  def saveYAML(sender)
    puts "Saving to #{@@defaultFile}"
    File.open(@@defaultFile, "w") {|f| f.print(@yamlArea.textStorage.mutableString)}
  end
  
  def validate(sender)
    case sender.state
    when NSOnState
      begin
        @profileManager.load @yamlArea.textStorage.mutableString
        sender.setTitle "Valid"
        self.setStatusText "Valid configuration. Select profile and click Rsync button."
        @configSelector.addItemsWithTitles @profileManager.paths
        @configSelector.selectItemAtIndex 0
        self.setReady true
        prefs["yaml_string"] = @yamlArea.textStorage.mutableString
        prefs.save
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
      activeProfile = @configSelector.titleOfSelectedItem
      now = Time.now.to_s
      prefs.setObject now, :forKey => :lastSyncDate
      prefs.setObject activeProfile, :forKey => :lastSyncProfile
      @lastSyncMenuItem.setTitle "Last Sync: #{now}"
      @lastProfileMenuItem.setTitle "Last Profile: #{activeProfile}"
      self.setStatusText "Starting rsync on #{activeProfile}..."
      self.setRsyncRunning true
      @msgArea.setString "Starting rsync on #{activeProfile}..."
      @profileManager.optList = prefs["rsyncOpts"]
      @rsync_thread = Thread.start(activeProfile) do |profs|
        closeButton = window.standardWindowButton(NSWindowCloseButton)
        closeButton.performSelectorOnMainThread("setEnabled:",
                                                withObject:false,
                                                waitUntilDone:true)
        begin
          @profileManager.select_path(profs).each do |prof,args|
            @msgArea.performSelectorOnMainThread("insertText:",
                                                 withObject:"\n\nStarting rsync with profile #{prof}\n",
                                                 waitUntilDone:true)
            cmd = "rsync " + (@profileManager.rsync_args(args) * ' ')
            @msgArea.performSelectorOnMainThread "insertText:", withObject:"#{cmd}\n", waitUntilDone:true 
            reader, writer = IO.pipe 
            @rsync_pid = spawn(cmd, [ STDERR, STDOUT ] => writer) 
            writer.close
            while out = reader.gets do
              @msgArea.performSelectorOnMainThread "insertText:", withObject:out, waitUntilDone:false 
            end
            @rsync_pid = nil
            self.performSelectorOnMainThread("setStatusText:",
                                             withObject:"Profile #{prof} successfully performed!",
                                             waitUntilDone:true)
            break if @abort
          end
        rescue
          puts "Error #{$!}"
        end
        self.performSelectorOnMainThread("setRsyncRunning:",
                                         withObject:false,
                                         waitUntilDone:true)
        closeButton.performSelectorOnMainThread("setEnabled:",
                                                withObject:true,
                                                waitUntilDone:true)
        @abort = false
        puts "Thread exiting"
      end
    end
  end
  
  def runThreaded(sender)
    if rsyncRunning then
      self.setStatusText "rsync already running: wait for termination."
    else
      active_profile = @configSelector.titleOfSelectedItem
      self.setStatusText "Starting rsync on #{active_profile}..."
      self.setRsyncRunning true
      @rsyncNSThread = NSThread.alloc.initWithTarget(self,
                                                     selector:'performRsync:',
                                                     object:active_profile)
      @rsyncNSThread.start
    end
  end
    
  def performRsync(active_profile)
    closeButton = window.standardWindowButton(NSWindowCloseButton)
    closeButton.setEnabled false
    areaLock = NSLock.new
    puts "****click!"
    @profileManager.select_path(active_profile).each do |prof,args|
      puts "****click!"
      areaLock.lock
      #@msgArea.insertText "\n\nStarting rsync with profile #{prof}\n"
      puts "****click!"
      cmd = "rsync " + (@profileManager.rsync_args(args) * ' ')
      #@msgArea.insertText cmd.inspect
      #@msgArea.insertText `#{cmd}`
      reader, writer = IO.pipe 
      @rsync_pid = spawn(cmd, [ STDERR, STDOUT ] => writer) 
      writer.close
      while out = reader.gets do
        #puts out
        @msgArea.performSelectorOnMainThread "insertText:", withObject:out, waitUntilDone:true
      end
      @rsync_pid = nil
      self.setStatusText "Profile #{prof} successfully performed!"
      areaLock.unlock
      break if @abort
    end
    self.setRsyncRunning false
    closeButton.setEnabled true
    @abort = false
    puts "Thread exiting"
  end
  
  def terminate(sender)
    if @rsync_pid then
      puts "Killing PID #{@rsync_pid}"
      Process.kill(:KILL, @rsync_pid)
    end
    @abort = true
    #@rsync_thread.exit if @rsync_thread.alive?
  end
  
  def windowWillClose(aNotification)
    puts "Saving preferences"
    prefs.save
  end
    
  def applicationWillTerminate(a_notification)
    puts "Closing"
    prefs.setObject @yamlArea.textStorage.mutableString, :forKey => :yaml_string
    prefs.save
    puts "Defaults saved"
    if @rsync_thread && @rsync_thread.alive?
      self.setStatusText "Waiting for rsync to terminate"
      @rsync_thread.join
    end
  end
  
  def applicationShouldTerminateAfterLastWindowClosed(application)
    false
    #prefs.valueForKeyPath("defaults.appMode") == 1
  end
  
end

