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
class AsyncHandler
  def initialize(target)
    @target = target
  end
  def data_ready(notification)
    data = notification.userInfo[NSFileHandleNotificationDataItem]
    output = NSString.alloc.initWithData(data, encoding: NSUTF8StringEncoding)
    @target.insertText output
  end
  def task_terminated(notification)
    @target.insertText "done"
  end
end

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
      #@rsync_thread = Thread.start(active_profile) do |profs|
        closeButton = window.standardWindowButton(NSWindowCloseButton)
        closeButton.setEnabled false
        @profileManager.select_path(active_profile).each do |prof,args|
          @msgArea.insertText "\n\nStarting rsync with profile #{prof}\n"
          cmd = "rsync " + (@profileManager.rsync_args(args) * ' ')
          @msgArea.insertText cmd.inspect
          #@msgArea.insertText `#{cmd}`
          self.dispatcher(@profileManager.rsync_args(args))
          self.setStatusText "Profile #{prof} successfully performed!"
          #@msgArea.insertText `#{cmd}`
          # @splitView.setPosition @splitView.bounds.size.width, ofDividerAtIndex:0
        end
        self.setRsyncRunning false
        closeButton.setEnabled true
      #end
    end
  end
  
  def terminate(sender)
    @rsync_thread.exit if @rsync_thread.alive?
    self.setStatusText "Profile #{@rbackup.args} currently is #{@rsync_thread.status.to_s}"
    self.setRsyncRunning false
    window.standardWindowButton(NSWindowCloseButton).setEnabled true
  end
  
  def dispatcher(args)
    #notification_handler = AsyncHandler.new(@msgArea)
    nc = NSNotificationCenter.defaultCenter
    
    task = NSTask.alloc.init
    pipe_out = NSPipe.alloc.init
    #pipe_err = NSPipe.alloc.init
    task.setEnvironment @environment
    p args
    task.arguments = args
    task.launchPath     = "/usr/bin/rsync"
    task.standardOutput = pipe_out
    #task.standardError = pipe_err
    [pipe_out].each do |pipe|
      file_handle = pipe.fileHandleForReading
      
      nc.addObserver(self,
                     selector: "data_ready:",
                     name: NSFileHandleReadCompletionNotification,
                     object: file_handle)
      
      file_handle.readInBackgroundAndNotify
    end
    nc.addObserver(self,
                   selector: "task_terminated:",
                   name: NSTaskDidTerminateNotification,
                   object: task)
    
    task.launch
  end
  
  def data_ready(notification)
    data = notification.userInfo[NSFileHandleNotificationDataItem]
    output = NSString.alloc.initWithData(data, encoding: NSUTF8StringEncoding)
    @msgArea.insertText output
  end
  
  def task_terminated(notification)
    puts "bing"
    @msgArea.insertText "done"
    self.setRsyncRunning false
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

