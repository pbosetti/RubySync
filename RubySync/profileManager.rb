#
#  profileManager.rb
#  RubySync
#
#  Created by Paolo Bosetti on 6/6/11.
#  Copyright 2011 Dipartimento di Ingegneria Meccanica e Strutturale. All rights reserved.
#
#  Based on code developed by Winton Welsh (http://github.com/winton) for rbackup gem.
#

require "yaml"
require "fileutils"

class ProfileManager
  attr_reader :profiles_data, :paths
  attr_accessor :optList
  def initialize
    @optList={}
    @yaml = ""
    @profile_data = {}
    @paths = []
  end
  
  def load(yaml)
    @yaml = ""
    @profile_data = {}
    @paths = []
    @profiles_data = YAML.load(yaml)
    self.get_paths
  end
  
  def get_paths(profile="",hash=@profiles_data)
    previous_level = profile
    hash.each do |k,v|
      profile += (profile.size > 0 ? ":" : "") + k
      @paths << profile
      if v["source"] then
        raise "Missing Destination" unless v["destination"]
      else
        get_paths(profile, v)
      end
      profile = previous_level
    end
  end
  
  def select_path(name)
    keys = name.split(":").map {|s| s}
    selection = @profiles_data
    keys.each {|k| selection = selection[k]}
    if selection['source'] then
      {name => selection}
    else
      selection
    end
  end
  
  def rsync_args(profile)
    inc1ude = []
    exclude = []
    destination = profile['destination']
    source = profile['source']
    
    options = %w|--numeric-ids --safe-links --executability -axzSvlE|
    # --numeric-ids               don't map uid/gid values by user/group name
    # --safe-links                ignore symlinks that point outside the tree
    # -a, --archive               recursion and preserve almost everything (-rlptgoD)
    # -u, --update                skip files that are newer on the receiver
    # -x, --one-file-system       don't cross filesystem boundaries
    # -z, --compress              compress file data during the transfer
    # -S, --sparse                handle sparse files efficiently
    # -v, --verbose               verbose
    # -l, --links                 copy symlinks as symlinks
    # -E, --extended-attributes copy extended attributes, resource forks
    # --executability         preserve executability
    
    if profile['delete'] or (profile['delete'].nil? and optList['delete'])
      options << "--delete"
      # --delete                  delete extraneous files from dest dirs
    end
    
    if profile['update'] or (profile['update'].nil? and optList['update'])
      options << "-u"
      # -u, --update                skip files that are newer on the receiver
    end
    
    if profile['dry'] or (profile['dry'].nil? and optList['dry'])
      options << "--dry-run"
      # --delete                  delete extraneous files from dest dirs
    end
    
    if destination.include?(':') || source.include?(':')
      options << '-e /usr/bin/ssh'
      # -e, --rsh=COMMAND         specify the remote shell to use
    else
      FileUtils.mkdir_p destination
    end
    
    if profile['include']
      exclude = %w(*) unless profile['exclude']
      inc1ude = [ profile['include'] ].flatten
    end

    if profile['exclude']
      exclude += [ profile['exclude'] ].flatten
    end
    
    inc1ude = inc1ude.collect { |i| "--include='#{i}'" }.join(' ')
    exclude = exclude.collect { |e| "--exclude='#{e}'" }.join(' ')
    # --exclude=PATTERN         use one of these for each file you want to exclude
    # --include-from=FILE       don't exclude patterns listed in FILE

    args = [options, inc1ude, exclude, esc(source), esc(destination)].flatten
  end
  
  private
  def esc(paths)
    paths = [ paths ].flatten
    paths.collect  { |path| 
      #      if path =~ /^~/ then
      #  path = path.stringByExpandingTildeInPath
      #end
      path.gsub(' ', '\ ')
  }.join(' ')
  end
  
end

if __FILE__ == $0 then
  yaml = <<-ENDYAML
Test:
  source: ~/Documents/Articoli
  destination: fraublucher.local.:~/Documents/
Documents:
  Articoli:
    source: ~/Documents/Articoli
    destination: fraublucher.local.:~/Documents/
  Ricerca:
    source: ~/Documents/Ricerca
    destination: fraublucher.local.:~/Documents/
    exclude:
      - "Vodafone data/"
      - "Manuale C4G.dmg"
  Didattica:
    source: ~/Documents/Didattica
    destination: fraublucher.local.:~/Documents/
    exclude:
      - Filmati/*
Prova:
  source: ~/Documents/Articoli
  destination: fraublucher.local.:~/Documents/
ENDYAML
  
  pm = ProfileManager.new
  pm.load yaml
  # p pm.select_path "Documents:Articoli"
  # p pm.select_path "Documents"
  # p pm.paths
  # pm.paths.each do |p|
  #   puts
  #   p pm.select_path p
  # end
  p pm.paths
  p pm.select_path("Documents")
  p pm.select_path("Documents:Articoli")
  pm.select_path("Documents:Articoli").each do |k,v|
    if v['source'] then 
      
    end
    puts "\n#{k}:"
    p pm.rsync_args(v)
  end
end