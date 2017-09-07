require 'fileutils'
require 'date'

class ExifData
  attr_accessor :xif, :date_created, :lat, :lon, :file

  def initialize file
    @file = file
    read_exif_data file
  end

  def read_exif_data file
    if @xif.to_s.empty?
      @xif =  `exiftool -c "%.6f" #{file}`
    end
  #  puts "file = #{file}: exif =#{@xif}"
    @xif
  end

  def get_created_date
    if @date_created.to_s.empty?
      created_date_lines = @xif.lines.grep /Create Date/
      if created_date_lines.length > 0
        @date_created = created_date_lines[0].match(/(\d+\:\d+\:\d+ \d+\:\d+\:\d+)/)
      else
        created_date_lines = @xif.lines.grep /File Modification Date/
        if created_date_lines.length > 0
          @date_created = created_date_lines[0].match(/(\d+\:\d+\:\d+ \d+\:\d+\:\d+)/)
        end
      end
    end
   begin
     @date_created =  DateTime.strptime(@date_created.to_s, '%Y:%m:%d %H:%M')
   rescue
     @date_created = File.stat(@file).mtime
   end
   @date_created
  end

  def get_lat_lon
    @lat = -1
    @lon = -1
      gps_lines = @xif.lines.grep /GPS Position|GPS Coordinates/
    if !gps_lines.empty?
      gps_lat_lon =  gps_lines[0].scan(/(\d+\.\d+)/)
      if gps_lat_lon.size > 0
        @lat = gps_lat_lon[0][0]
        @lon = gps_lat_lon[1][0]
      end
    end
  end

 def get_lat
   if @lat.to_s.empty?
     get_lat_lon
   end
   @lat
 end

 def get_lon
   if @lat.to_s.empty?
     get_lat_lon
   end
   @lon
 end
end


# pic_path = File.join()
# all = Dir.glob("/Users/bpaul/Desktop/test-sort-pics/IMG_34481.JPG")
# # all = Dir.glob("/Users/bpaul/Desktop/test-sort-pics/*{.JPG}")
# all.each do |file|
# x = ExifData.new(file)
#
#  puts  x.read_exif_data file
#   puts "#{file} = date: #{x.get_created_date}, lat=#{x.get_lat}, lon=#{x.get_lon}"
# end
