require 'webrick'
require 'webrick/httpproxy'
require 'uri'
require 'base64'
require 'zlib'
require 'tmpdir'
require 'yaml'
require 'rexml/document'
require './mill_and_knead'
require './tank'
require 'bundler'
Bundler.require

module WEBrick
  class HTTPRequest
    # for long URL
    remove_const(:MAX_URI_LENGTH)
    MAX_URI_LENGTH = 208300
  end
end

config = YAML.load_file("config.yml").to_h
tank = Tank.new

def retrieve_swf_version_if_hit(url, swf_name)
  regexp_escaped = swf_name.gsub(/(\/|\.)/, '\\\\\1')
  if url =~ /^http:\/\/[0-9.]+\/kcs\/#{regexp_escaped}\?(?:version|VERSION)=((?:\d+\.?)+)/
    $1
  else
    nil
  end
end

def hit_sound?(url, sound_name)
  regexp_escaped = sound_name.gsub(/(\/|\.)/, '\\\\\1')
  puts "#{url} #{sound_name} #{url =~ /^http:\/\/[0-9.]+\/kcs\/#{regexp_escaped}/}"
  url =~ /^http:\/\/[0-9.]+\/kcs\/#{regexp_escaped}/
end

request_callback = proc { |req, res|
  if not config["swf"].nil?
    config["swf"].each do |swf_name, replacement|
      version = retrieve_swf_version_if_hit(req.request_uri.to_s, swf_name)
      if not version.nil?
        if not req['If-None-Match'].nil?
          if_none_match = req['If-None-Match']
        elsif not req['If-Range'].nil?
          if_none_match = req['If-Range']
        end
        if (not if_none_match.nil?) and if_none_match == tank.get_swf_entity_tag(swf_name)
          raise WEBrick::HTTPStatus::NotModified
        elsif tank.has_the_same_swf?(swf_name, version, replacement)
          res.body = tank.get_cached_raw_data(swf_name)
          res['ETag'] = tank.get_swf_entity_tag(swf_name)
          res['Expires'] = Time.now.strftime('%a, %d %b %Y %T %z') # RFC 1123
          raise WEBrick::HTTPStatus::OK
        end
      end
    end
  end
  if not config["sound"].nil?
    config["sound"].each do |sound_name, replacement|
      if hit_sound?(req.request_uri.to_s, sound_name)
        if not req['If-None-Match'].nil?
          if_none_match = req['If-None-Match']
        elsif not req['If-Range'].nil?
          if_none_match = req['If-Range']
        end
        if (not if_none_match.nil?) and if_none_match == tank.get_raw_data_entity_tag(sound_name)
          raise WEBrick::HTTPStatus::NotModified
        else
          res.body = tank.get_raw_data(replacement)
          tank.save_list
          res['ETag'] = tank.get_raw_data_entity_tag(sound_name)
          res['Expires'] = Time.now.strftime('%a, %d %b %Y %T %z') # RFC 1123
          raise WEBrick::HTTPStatus::OK
        end
      end
    end
  end
}

proxy_content_handler = proc { |req, res|
  if not config["swf"].nil?
    config["swf"].each do |swf_name, replacement|
      version = retrieve_swf_version_if_hit(req.request_uri.to_s, swf_name)
      if not version.nil?
        mk = MillAndKnead.new(res.body, tank)
        mk.replace_swf_data(replacement)
        raw_swf = mk.get_raw_swf
        if not raw_swf.nil?
          tank.save_raw_swf(swf_name, raw_swf, version, replacement)
          res.body = raw_swf
          if not res['Last-Modified'].nil?
            res.header.delete('Last-Modified')
          end
          res['ETag'] = tank.get_swf_entity_tag(swf_name)
          res['Expires'] = Time.now.strftime('%a, %d %b %Y %T %z') # RFC 1123
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
  :ProxyContentHandler => proxy_content_handler,
  :RequestCallback => request_callback
)

Signal.trap('INT') do
  s.shutdown
end

s.start

