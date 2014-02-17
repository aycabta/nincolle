require 'yaml'
require 'digest/md5'

# "http://hogehoge.hoge/hogehoge.jpg":
#   filenum: 0
#   filename: "0"
#   last_modified: YYYY-MM-DD hh:mm:ss
# "http://kiee.net/pao.gif":
#   filenum: 1
#   filename: "1"
#   etag: "fj9349fg9349J934"
# "ship/118.swf":
#   filenum: 2
#   filename: "2"
#   version: 1
#   ninversion: 3
#   replacement:
#     1: ...
#     3: ...
#     ...

class Tank
  def initialize
    if not Dir.exist?("cache")
      Dir.mkdir("cache")
    end
    @list = {}
    @filenum = 0
    if File.exist?("cache_list.yml")
      open("cache_list.yml", "r") do |f|
        yaml = YAML.load(f.read)
        if yaml
          @list = yaml.to_h
          update_counter
        end
      end
    end
    @prev_list = @list.dup
  end

  def update_counter
    max_filenum = 0
    @list.each do |url, values|
      if values[:filenum] > max_filenum
        max_filenum = values[:filenum]
      end
    end
    @filenum = max_filenum
  end

  def save_list
    if not @list.eql?(@prev_list)
      open("cache_list.yml", "w") do |f|
        f.write(@list.to_yaml)
        @prev_list = @list.dup
      end
    end
  end

  def get_remote_file(url)
    file_data = @list[url]
    uri = URI.parse(url)
    req = Net::HTTP::Get.new(uri.request_uri)
    if not file_data.nil? and not file_data[:last_modified].nil?
      req['If-Modified-Since'] = file_data[:last_modified].strftime('%a, %d %b %Y %T %z') # RFC 1123
    end
    if not file_data.nil? and not file_data[:etag].nil?
      req['If-None-Match'] = file_data[:etag]
    end
    http = Net::HTTP.new(uri.host, uri.port)
    res = http.request(req)
    if res.nil?
      puts "error: #{url}"
    elsif res.kind_of?(Net::HTTPSuccess)
      last_modified = DateTime.rfc2822(res['Last-Modified'])
      etag = res['ETag']
      if file_data.nil?
        @filenum += 1
        filename = "#{@filenum}"
        file_data = {
          :filenum => @filenum,
          :filename => filename,
          :last_modified => last_modified,
          :etag => etag
        }
      else
        file_data[:last_modified] = last_modified
        file_data[:etag] = etag
      end
      open("cache/#{file_data[:filename]}", "w") do |f|
        f.write(res.body)
        @list[url] = file_data
      end
      res.body
    elsif res.kind_of?(Net::HTTPNotModified)
      f = File.open("cache/#{file_data[:filename]}", "r")
      if f.nil?
        puts "cache/#{file_data[:filename]} open error"
        nil
      else
        new_media_data = f.read
        f.close
        new_media_data
      end
    else
      puts "error: #{res['Status']} #{res.class.name} #{res.message} #{url}"
      nil
    end
  end

  def get_raw_data(name)
    if name =~ /^https?:\/\//
      get_remote_file(name)
    else
      f = File.open("replacement/#{name}", "r")
      if f.nil?
        puts "replacement/#{name} open error"
        nil
      else
        new_media_data = f.read
        f.close
        new_media_data
      end
    end
  end
end

