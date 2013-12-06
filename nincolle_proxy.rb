require 'webrick'
require 'webrick/httpproxy'
require 'uri'
require 'base64'
require 'zlib'
require 'tmpdir'
require 'yaml'
require 'rexml/document'

module WEBrick
  class HTTPRequest
    # for long URL
    MAX_URI_LENGTH = MAX_URI_LENGTH = 208300
  end
end

$fuck_count = 0

$DEFINE_TAGS_FOR_REPLACEMENT = [
  "DefineBits",
  "DefineSound",
  "DefineBitsLossless",
  "DefineBitsJPEG2",
  "DefineBitsJPEG3",
  "DefineBitsLossless2",
  "DefineBitsJPEG4"
]

def replace_data(xmldoc, id, new_data)
  if id.kind_of?(String)
    export = REXML::XPath.first(xmldoc, "//Export/symbols/Symbol[@name=\"#{id}\"]")
    object_id = export.attributes["objectID"]
    REXML::XPath.each(export.parent, "//*[@objectID=\"#{object_id}\"]") do |element|
      if $DEFINE_TAGS_FOR_REPLACEMENT.include?(element.name)
        element.elements["data"].elements["data"].text = Base64.strict_encode64(new_data)
        break
      end
    end
  elsif id.kind_of?(Fixnum)
    REXML::XPath.each(xmldoc, "//*[@objectID=\"#{id}\"]") do |element|
      if $DEFINE_TAGS_FOR_REPLACEMENT.include?(element.name)
        element.elements["data"].elements["data"].text = Base64.strict_encode64(new_data)
        break
      end
    end
  end
end

def mill_swf2xml_to_raw(filename)
  result = `swfmill swf2xml #{Dir.tmpdir}/#{filename}.swf #{Dir.tmpdir}/#{filename}.xml`
  if $? != 0
    puts "swfmill swf2xml error: #{result}"
    return nil
  end
  f = File.open("#{Dir.tmpdir}/#{filename}.xml", "r")
  if f.nil?
    puts "#{filename}.xml open error"
    return nil
  end
  raw_xml_data = f.read
  f.close
  raw_xml_data
end

def mill_xml2swf_to_raw(filename)
  result = `swfmill xml2swf #{Dir.tmpdir}/#{filename}.xml #{Dir.tmpdir}/#{filename}_new.swf`
  if $? != 0
    puts "swfmill xml2swf error: #{result}"
    return nil
  end
  f = File.open("#{Dir.tmpdir}/#{filename}_new.swf", "r")
  if f.nil?
    puts "#{filename}_new.swf open error"
    return nil
  end
  raw_swf_data = f.read
  f.close
  raw_swf_data
end

def replace_swf_datas(orig_swf_data, replace_pairs)
  filename = "nincolle_#{$fuck_count}"
  $fuck_count += 1

  f = File.open("#{Dir.tmpdir}/#{filename}.swf", "w")
  if f.nil?
    puts "#{filename}.swf open error"
    return nil
  end
  f.write(orig_swf_data)
  f.close

  raw_xml_data = mill_swf2xml_to_raw(filename)
  if raw_xml_data.nil?
    return nil
  end
  xmldoc = REXML::Document.new(raw_xml_data)

  replace_pairs.each do |orig, dest|
    # TODO: support URL
    f = File.open("replacement/#{dest}", "r")
    if f.nil?
      puts "replacement/#{dest} open error"
      next
    end
    new_media_data = f.read
    f.close
    replace_data(xmldoc, orig, new_media_data)
  end

  f = File.open("#{Dir.tmpdir}/#{filename}.xml", "w")
  if f.nil?
    puts "#{filename}.xml open error"
    return nil
  end
  f.write(xmldoc.to_s)
  f.close

  mill_xml2swf_to_raw(filename)
end

config = YAML.load_file("config.yml").to_h

handler = proc { |req, res|
  if not config["swf"].nil?
    config["swf"].each do |swf_name, replacement|
      regexp_escaped = swf_name.gsub(/(\/|\.)/, '\\\\\1')
      if req.request_uri.to_s =~ /^http:\/\/125\.6\.187\.229\/kcs\/#{regexp_escaped}\?(version|VERSION)=(\d+\.?)+/
        puts "url: #{req.request_uri.to_s}"
        puts "detect for: #{swf_name}"
        puts "replacement: #{replacement.to_s}"
        swf = replace_swf_datas(res.body, replacement)
        res.body = swf
      end
    end
  end
}

s = WEBrick::HTTPProxyServer.new(
  :BindAddress => '127.0.0.1',
  :Port => 8080,
  :Logger => WEBrick::Log::new($stderr, WEBrick::Log::DEBUG),
  :ProxyVia => true,
  :ProxyContentHandler => handler
)

Signal.trap('INT') do
  s.shutdown
end

s.start

