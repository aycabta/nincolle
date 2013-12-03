require 'base64'
require 'rexml/document'

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
    ext = MEDIA_TAG_TO_EXT[element.name]
    if not ext.nil?
      File.open("#{element.attributes["objectID"]}.#{ext}", "w") do |f|
        f.write(Base64.decode64(element.elements["data"].elements["data"].text))
      end
    end
  end
end


