require 'date'
require 'open-uri'
require 'json'
require 'fileutils'
require 'shellwords'
require './exif-data.rb'
require './FolderUtils.rb'

class PictureFile
  attr_accessor :name, :created_on, :lat, :lon
  def initialize(name)
    @name = name
  end
end

class PicturesSort
  attr_accessor :folder, :file_types
  @folderHash
  @picture_filesHash

  def initialize(folder, file_types)
    @folder = folder
    @file_types = file_types
    @picture_filesHash = Hash.new{|hash, key| hash[key] = Hash.new}
  end

  def sort_files
    folderHash = Hash.new {|h,k| h[k]=[]}
    Dir.chdir(@folder)
    #path = "#{@folder}*{#{@file_types}}"
    path = "*{#{@file_types}}"
    all = Dir.glob(path)
      all.each do |file|
      excapedFile = file.gsub(/ /, '\ ')
      begin
        if picture_file = get_exif_data(excapedFile)
            line =  "#{file} = #{sprintf('%.2f',picture_file.lat)},#{sprintf('%.2f',picture_file.lon)},#{picture_file.created_on}"
            puts line
            File.write("#{@folder}output.log", line+"\n", File.size("#{@folder}output.log"), mode: 'a')
            folderHash["#{sprintf('%.2f',picture_file.lat)},#{sprintf('%.2f',picture_file.lon)},#{picture_file.created_on.strftime("%B%d-%Y")}"] << file.shellescape
        end
      rescue
        puts "Exception here for the file #{file}"
        File.write("#{@folder}output.log", "Exception for file: #{file}", File.size("#{@folder}output.log"), mode: 'a')
      end
    end
    get_location_file_hash(folderHash)
  end


  def get_location_file_hash(folderHash)
      folderNameHash = Hash.new {|h,k| h[k]=[]}
      puts "folderHash = #{folderHash}"
      folderHash.each do |key, value|
      firstFile = value[0]
      puts "fetching location for #{key}"
      begin
        url =  "https://maps.googleapis.com/maps/api/geocode/json?latlng=#{@picture_filesHash[firstFile].lat},-#{@picture_filesHash[firstFile].lon}&key=AIzaSyCEBXf9rwYCgPEFPRDK1bg_6WsPphgxg3Q"
        #puts "url=#{url}"
        response = open(url)
        shortname = JSON.load(response)['results'][0]['address_components'][1]['short_name']
      rescue
        shortname = "no_location"
      end
      d = @picture_filesHash[firstFile].created_on
      create_date = d.strftime("%B%d-%Y")
      puts "Adding into folderNameHash= #{value}"
      folderNameHash[create_date+shortname.sub(' ','_')] += value
    end
    folderNameHash
  end


  def get_exif_data file
    picture_file = PictureFile.new(file)
    exif_data = ExifData.new(file)
    picture_file.lat = exif_data.get_lat
    picture_file.lon = exif_data.get_lon
    picture_file.created_on = exif_data.get_created_date
    @picture_filesHash[file] = picture_file
    picture_file
  end
end
#
# all = Dir.glob("/Users/bpaul/Desktop/test-sort-pics/*{.JPG}")

pic_sort = PicturesSort.new("/Users/bpaul/Desktop/testing/", "MOV,JPG,jpg,MP4,PNG,mp4")
#  pic_sort = PicturesSort.new(".", "MOV")
folderNameHash =  pic_sort.sort_files
puts "folderNameHash = #{folderNameHash}"
folder_util = FolderUtils.new
folder_util.base_folder = "/Users/bpaul/Desktop/testing"
folderNameHash.each do |key, value|
  folder_util.create_folder_move_files(key, value)
end
