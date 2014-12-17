class Fluent::FiveRocksOutput < Fluent::BufferedOutput
  Fluent::Plugin.register_output('5rocks', self)

  config_param :url_base, :string, :default => "https://server.api.5rocks.io/sev/1/"

  attr_reader :url, :field_map

  def initialize
    super
    require 'net/http'
    require 'uri'
  end

  def configure(conf)
    super
    @url = "#{@url_base}#{conf['app_id']}"
    @field_map = {
      'app_key' => conf['app_key'],
      'name' => conf['name'],
      'category' => conf['category'],
    }
    conf.elements.select { |e|
      e.name == "field"
    }.each { |f|
      f.each_key { |k| @field_map[k] = f[k]}

      f.elements.select { |ee|
        ee.name == "values"
      }.each { |m|
        m.each_key{ |k| @field_map["values[#{k}]"] = m[k]}
      }
    }
  end

  def start
    super
  end

  def shutdown
    super
  end

  def format(tag, time, record)
    [tag, time, record].to_msgpack
  end

  def write(chunk)
    ret = []
    chunk.msgpack_each do |tag, time, record|
      params = @field_map.each_with_object({}) do |(k, v), p|
        p[k] = v.gsub(/\$\((.+)\)/) { record[$1] }
      end
      log.debug "request parameters: #{params}"
      res = Net::HTTP.post_form(URI.parse(@url), params)
      log.debug "response code: #{res.code}"
      log.debug "response body: #{res.body}"
      
      ret << params
      raise "failed to insert into 5rocks" unless res.code == "201"
    end
    return ret
  end
end
