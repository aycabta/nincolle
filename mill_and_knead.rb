require 'tmpdir'
require './filling'
require 'bundler'
Bundler.require

class MillAndKnead
  @@fuck_count = 0

  def initialize(orig_raw_swf)
    @filename = "nincolle_#{@@fuck_count}"
    @@fuck_count += 1
    raw_xml_data = mill_swf2xml_to_raw(orig_raw_swf)
    if not raw_xml_data.nil?
      @xmldoc = REXML::Document.new(raw_xml_data)
      if @xmldoc.nil?
        puts "#{@filename}.xml is not valid"
      end
    end
  end

  def mill_swf2xml_to_raw(orig_raw_swf)
    f = File.open("#{Dir.tmpdir}/#{@filename}.swf", "w")
    if f.nil?
      puts "#{@filename}.swf open error"
      return nil
    end
    f.write(orig_raw_swf)
    f.close

    result = `swfmill swf2xml #{Dir.tmpdir}/#{@filename}.swf #{Dir.tmpdir}/#{@filename}.xml`
    if $? != 0
      puts "swfmill swf2xml error: #{result}"
      return nil
    end
    f = File.open("#{Dir.tmpdir}/#{@filename}.xml", "r")
    if f.nil?
      puts "#{@filename}.xml open error"
      return nil
    end
    raw_xml_data = f.read
    f.close
    raw_xml_data
  end

  def replace_data(id, new_data)
    if id.kind_of?(String)
      export = REXML::XPath.first(@xmldoc, "//Export/symbols/Symbol[@name=\"#{id}\"]")
      object_id = export.attributes["objectID"]
      REXML::XPath.each(export.parent, "//*[@objectID=\"#{object_id}\"]") do |element|
        if $DEFINE_TAGS_FOR_REPLACEMENT.include?(element.name)
          element.elements["data"].elements["data"].text = Base64.strict_encode64(new_data)
          break
        end
      end
    elsif id.kind_of?(Fixnum)
      REXML::XPath.each(@xmldoc, "//*[@objectID=\"#{id}\"]") do |element|
        if $DEFINE_TAGS_FOR_REPLACEMENT.include?(element.name)
          element.elements["data"].elements["data"].text = Base64.strict_encode64(new_data)
          break
        end
      end
    end
  end

  def replace_swf_data(replace_pairs)
    if not @xmldoc.nil?
      replace_pairs.each do |orig_id, dest|
        replace_data(orig_id, Filling.get_raw_data(dest))
      end
    end
  end

  def mill_xml2swf_to_raw
    result = `swfmill xml2swf #{Dir.tmpdir}/#{@filename}.xml #{Dir.tmpdir}/#{@filename}_new.swf`
    if $? != 0
      puts "swfmill xml2swf error: #{result}"
      return nil
    end
    f = File.open("#{Dir.tmpdir}/#{@filename}_new.swf", "r")
    if f.nil?
      puts "#{@filename}_new.swf open error"
      return nil
    end
    raw_swf_data = f.read
    f.close
    raw_swf_data
  end

  def get_raw_swf
    if @xmldoc.nil?
      nil
    else
      f = File.open("#{Dir.tmpdir}/#{@filename}.xml", "w")
      if f.nil?
        puts "#{@filename}.xml open error"
        return nil
      end
      f.write(@xmldoc.to_s)
      f.close

      mill_xml2swf_to_raw
    end
  end
end

