#
#  AppDelegate.rb
#  RubySync
#
#  Created by Paolo Bosetti on 6/1/11.
#  Copyright 2011 Dipartimento di Ingegneria Meccanica e Strutturale. All rights reserved.
#
require "yaml"

resources_path = NSBundle.mainBundle.resourcePath.fileSystemRepresentation
require "#{resources_path}/profileManager"

# see http://ofps.oreilly.com/titles/9781449380373/_foundation.html

class AppDelegate
  attr_accessor :ready, :rsyncRunning
  attr_accessor :window
  attr_accessor :yamlArea, :msgArea
  attr_accessor :configSelector
  attr_accessor :statusText
  attr_accessor :splitView
  attr_accessor :messageLog

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
    @profileManager = ProfileManager.new
    @configSelector.removeAllItems
    if @@user_defaults.objectForKey(:yaml_string)
        @yamlArea.insertText @@user_defaults.objectForKey(:yaml_string)
    end
    self.setReady false
    self.setRsyncRunning false
    self.setStatusText ""
    @splitView.setAutosaveName "splitView"
    @environment = NSProcessInfo.processInfo.environment
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
        @profileManager.load @yamlArea.textStorage.mutableString
        sender.setTitle "Valid"
        self.setStatusText "Valid configuration. Select profile and click Rsync button."
        @configSelector.addItemsWithTitles @profileManager.paths
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
      self.setStatusText "Starting rsync on #{active_profile}..."
      self.setRsyncRunning true
      @msgArea.setString "Starting rsync on #{active_profile}..."
      @rsync_thread = Thread.start(active_profile) do |profs|
        closeButton = window.standardWindowButton(NSWindowCloseButton)
        closeButton.performSelectorOnMainThread("setEnabled:",
                                                withObject:false,
                                                waitUntilDone:true)
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
    #self.setStatusText "Profile #{@configSelector.titleOfSelectedItem} currently is #{@rsync_thread.status.to_s}"
    #self.setRsyncRunning false
    #window.standardWindowButton(NSWindowCloseButton).setEnabled true
  end
      
  def applicationWillTerminate(a_notification)
    puts "Closing"
    @@user_defaults.setObject @yamlArea.textStorage.mutableString, :forKey => :yaml_string
    puts "Defaults saved"
    if @rsync_thread && @rsync_thread.alive?
      self.setStatusText "Waiting for rsync to terminate"
      @rsync_thread.join
    end
  end
  
  def applicationShouldTerminateAfterLastWindowClosed(application)
    true
  end
  
end

