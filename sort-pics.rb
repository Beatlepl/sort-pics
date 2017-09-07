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
  attr_accessor :folder, :file_types, :api_key, :folderUtils, :known_locations
  @folderHash
  @picture_filesHash

  def initialize(folder, file_types, api_key)
    @folder = folder
    @file_types = file_types
    @api_key = api_key
    @picture_filesHash = Hash.new{|hash, key| hash[key] = Hash.new}
    @folderUtils = FolderUtils.new
    @folderUtils.base_folder = folder
    @known_locations = JSON.parse(File.read("#{File.dirname(__FILE__)}/locations.json"))
  end

  def sort_files_bylocation
    folderHash = Hash.new {|h,k| h[k]=[]}
    dateLatLonArrayHash = Hash.new {|h,k| h[k]=[]}
    dateNoLocationArrayHash = Hash.new {|h,k| h[k]=[]}
    Dir.chdir(@folder)
    #path = "#{@folder}*{#{@file_types}}"
    path = "*{#{@file_types}}"
    all = Dir.glob(path)
    total_files = all.size
      all.each_with_index do |file, index|
      excapedFile = file.shellescape
      begin
        puts "#{index}/#{total_files} - #{excapedFile}"
        if picture_file = get_exif_data(excapedFile)
          line =  "#{picture_file.name} = #{picture_file.lat},#{picture_file.lon},#{picture_file.created_on}"
          puts line
          File.write("#{@folder}output.log", line+"\n", File.size("#{@folder}output.log"), mode: 'a')
          if picture_file.lat == -1
            dateNoLocationArrayHash[picture_file.created_on.strftime("%B%d-%Y")] << picture_file.name
          else
            folderHash["#{sprintf('%.2f',picture_file.lat)},#{sprintf('%.2f',picture_file.lon)}"] << file.shellescape
            dateLatLonArrayHash[picture_file.created_on.strftime("%B%d-%Y")] << "#{sprintf('%.2f',picture_file.lat)},#{sprintf('%.2f',picture_file.lon)}"
          end
        end
      rescue
        puts "Exception here for the file #{picture_file.name}"
        File.write("#{@folder}output.log", "Exception for file: #{picture_file.name}", File.size("#{@folder}output.log"), mode: 'a')
      end
    end
    move_nolocation_file(dateLatLonArrayHash, dateNoLocationArrayHash, folderHash )
    get_location_file_hash(folderHash)
  end

  def move_nolocation_file(dateLatLonArrayHash, dateNoLocationArrayHash, folderHash)
    #Find the location where max photos taken in a given date
    dateLatLonArrayHash.each do |date, latlon_arr|
      uniq_lat_lon_arr = latlon_arr.uniq
      max_latlon = ""
      max_latlon_cnt = 0
      uniq_lat_lon_arr.each do |uniq_lat_lon|
        if latlon_arr.count(uniq_lat_lon) >= max_latlon_cnt
          max_latlon_cnt = latlon_arr.count(uniq_lat_lon)
          max_latlon = uniq_lat_lon
        end
      end
      dateLatLonArrayHash[date] = max_latlon
    end


    # move the no loc pics to its correct hash
    dateNoLocationArrayHash.each do |date, no_loc_array|
      if dateLatLonArrayHash[date].size  > 0
        folderHash[dateLatLonArrayHash[date]] << no_loc_array
        folderHash[dateLatLonArrayHash[date]].flatten!
      else
          folderHash[date] << no_loc_array
          folderHash[date].flatten!
      end
    end
  end

  def get_location_file_hash(folderHash)
      folderNameHash = Hash.new {|h,k| h[k]=[]}
      # puts "@picture_filesHash = #{@picture_filesHash}"
      folderHash.each do |key, value|
      firstFile = value[0]
      puts "Fetching location for #{key}...firstFile=#{firstFile}"
      if key.include? ","
        begin
          # puts "=======created on #{@picture_filesHash[firstFile]}"
          d = @picture_filesHash[firstFile].created_on
          create_date = d.strftime("%B%d-%Y")
          if @known_locations.has_key? key
            shortname = @known_locations[key]
          else
            url =  "https://maps.googleapis.com/maps/api/geocode/json?latlng=#{@picture_filesHash[firstFile].lat},-#{@picture_filesHash[firstFile].lon}&key=#{@api_key}"
            puts "url=#{url}"
            response = open(url)
            shortname = JSON.load(response)['results'][0]['address_components'][1]['short_name']
          end
          folderNameHash[create_date+shortname.gsub(' ','_')] += value
        rescue
          folderNameHash[key] += value
        end
      else
        folderNameHash[key] += value
      end
    end
    folderNameHash
  end

  # Deprecated
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
            folderHash["#{sprintf('%.2f',picture_file.lat)},#{sprintf('%.2f',picture_file.lon)},#{picture_file.created_on.strftime("%B%d-%Y")}"] << file
        end
      rescue
        puts "Exception here for the file #{file}"
        File.write("#{@folder}output.log", "Exception for file: #{file}", File.size("#{@folder}output.log"), mode: 'a')
      end
    end
    get_location_file_hash(folderHash)
  end

  def get_exif_data file
    picture_file = PictureFile.new(file)
    exif_data = ExifData.new(file)
    picture_file.lat = exif_data.get_lat
    picture_file.lon = exif_data.get_lon
    picture_file.created_on = exif_data.get_created_date
    if picture_file.lat == -1
      if !picture_file.name.include?("NL-")
        @folderUtils.rename_file(file, "NL-#{file}")
        picture_file.name = "NL-#{file}"
      end
    end
    @picture_filesHash[file] = picture_file
    picture_file
  end
end

if ARGV.length == 2
  pic_sort = PicturesSort.new(ARGV[0], "MOV,JPG,jpg,MP4,PNG,mp4", ARGV[1])
  folderNameHash =  pic_sort.sort_files_bylocation
  puts "folderNameHash = #{folderNameHash}"
  folder_util = FolderUtils.new
  folder_util.base_folder = ARGV[0]
  folderNameHash.each do |key, value|
    folder_util.create_folder_move_files(key, value)
  end
else
  puts "Please provide two argument to the program. sort-pics.rb /path/to/the/picutres/folder/ googleAPIKey"
end
