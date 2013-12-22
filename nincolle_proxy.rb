require 'webrick'
require 'webrick/httpproxy'
require 'uri'
require 'base64'
require 'zlib'
require 'tmpdir'
require 'yaml'
require 'rexml/document'
require './mill_and_knead'

module WEBrick
  class HTTPRequest
    # for long URL
    remove_const(:MAX_URI_LENGTH)
    MAX_URI_LENGTH = 208300
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

config = YAML.load_file("config.yml").to_h

handler = proc { |req, res|
  if not config["swf"].nil?
    config["swf"].each do |swf_name, replacement|
      regexp_escaped = swf_name.gsub(/(\/|\.)/, '\\\\\1')
      if req.request_uri.to_s =~ /^http:\/\/[0-9.]+\/kcs\/#{regexp_escaped}\?(version|VERSION)=(\d+\.?)+/
        puts "url: #{req.request_uri.to_s}"
        puts "detect for: #{swf_name}"
        puts "replacement: #{replacement.to_s}"
        mk = MillAndKnead.new(res.body)
        mk.replace_swf_data(replacement)
        raw_swf = mk.get_raw_swf
        if not raw_swf.nil?
          res.body = raw_swf
        end
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

