#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'iDENTify.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'iDENTify' }

# Add each file individually
files = [
  'iDENTify/Models/CameraSourceType.swift',
  'iDENTify/Models/CavityDetectionModels.swift',
  'iDENTify/Models/NavigationState.swift',
  'iDENTify/Services/CavityDetectionService.swift',
  'iDENTify/Utilities/ImageProcessingUtils.swift',
  'iDENTify/ViewModels/CameraViewModel.swift',
  'iDENTify/Views/ImagePicker.swift',
  'iDENTify/Views/ImagePreviewView.swift',
  'iDENTify/Views/ResultsView.swift',
  'iDENTify/Views/Components/CavityDetectionCard.swift'
]

files.each do |file_path|
  if File.exist?(file_path)
    file_ref = project.main_group.find_subpath(file_path, true)
    if file_ref
      # Check if already added to target
      already_added = target.source_build_phase.files.any? { |f| f.file_ref == file_ref }
      unless already_added
        target.add_file_references([file_ref])
        puts "Added: #{file_path}"
      else
        puts "Already exists: #{file_path}"
      end
    else
      puts "Could not find file reference: #{file_path}"
    end
  else
    puts "File does not exist: #{file_path}"
  end
end

project.save
puts 'Project saved successfully'
