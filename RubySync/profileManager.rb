#
#  profileManager.rb
#  RubySync
#
#  Created by Paolo Bosetti on 6/6/11.
#  Copyright 2011 Dipartimento di Ingegneria Meccanica e Strutturale. All rights reserved.
#
require "yaml"

class ProfileManager
  attr_reader :profiles_data, :paths
  def initialize
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
    hash.each do |k,v|
      previous_level = profile
      profile += (profile.size > 0 ? ":" : "") + k
      @paths << profile
      if v["source"] then
        profile = previous_level
      else
        get_paths(profile, v)
      end
    end
  end
  
  def select_path(name)
    keys = name.split(":").map {|s| s}
    selection = @profiles_data
    keys.each {|k| selection = selection[k]}
    selection
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
ENDYAML
  
  pm = ProfileManager.new
  pm.load yaml
  p pm.select_path "Documents:Articoli"
  p pm.select_path "Documents"
  p pm.paths
  pm.paths.each do |p|
    puts
    p pm.select_path p
  end
    
end