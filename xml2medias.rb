require 'base64'
require 'rexml/document'
require 'bundler'
Bundler.require

if ARGV.size < 1
  puts "usage: ruby xml2medias.rb converted_from_swf.xml"
  exit 0
end

MEDIA_TAG_TO_EXT = {
  "DefineBits" => "jpg",
  "DefineSound" => "mp3",
  "DefineBitsLossless" => "png",
  "DefineBitsJPEG2" => "jpg",
  "DefineBitsJPEG3" => "jpg",
  "DefineBitsLossless2" => "png",
  "DefineBitsJPEG4" => "jpg"
}

File.open(ARGV[0], "r") do |f|
  xmldoc = REXML::Document.new(f)
  REXML::XPath.each(xmldoc, "//*[@objectID]") do |element|
    object_id = element.attributes["objectID"]
    ext = MEDIA_TAG_TO_EXT[element.name]
    if not ext.nil?
      export = REXML::XPath.first(xmldoc, "//Export/symbols/Symbol[@objectID=\"#{object_id}\"]")
      if not export.nil?
        filename = "#{object_id}_#{export.attributes["name"]}.#{ext}"
      else
        filename = "#{object_id}.#{ext}"
      end
      puts filename
      File.open(filename, "w") do |f|
        f.write(Base64.decode64(element.elements["data"].elements["data"].text))
      end
    end
  end
end


