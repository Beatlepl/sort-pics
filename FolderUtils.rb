require 'fileutils'

class FolderUtils
 attr_accessor :base_folder

 def initialize
 end

 def create_folder folder_name
    dirname = File.dirname("#{@base_folder}/#{folder_name}")
    unless File.directory?("#{@base_folder}/#{folder_name}")
      FileUtils.mkdir_p("#{@base_folder}/#{folder_name}")
    end
  end

  def create_folder_move_files(folder, files)
    create_folder folder
    files.each do |file|
      move_file(file, folder)
    end
  end

  def move_file (file, folder)
    FileUtils.mv("#{file.sub('\\','')}", "#{@base_folder}/#{folder}/#{file.sub('\\','')}")
  end
end
