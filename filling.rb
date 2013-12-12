class Filling
  def self.get_raw_data(name)
    # TODO: support URL
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

