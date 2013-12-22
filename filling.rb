require 'net/http'
require 'uri'

class Filling
  def self.get_raw_data(name)
    if name =~ /^https?:\/\//
      uri = URI.parse(name)
      res = Net::HTTP.get_response(uri)
      if res.nil?
        nil
      else
        res.body
      end
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

