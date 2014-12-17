class Fluent::FiveRocksOutput < Fluent::BufferedOutput
  Fluent::Plugin.register_output('5rocks', self)

  config_param :url_base, :string, :default => "https://server.api.5rocks.io/sev/1/"

  attr_reader :url, :field_map

  def initialize
    super
    require 'net/http'
    require 'uri'
    require "time"
  end

  def configure(conf)
    super
    @url = "#{@url_base}#{conf['app_id']}"
    @field_map = {
      'app_key' => conf['app_key'],
      'name' => conf['name'],
    }
    @field_map['category'] = conf['category'] if conf['category']
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
      log.debug "record from fluentd: #{record}"

      params = @field_map.each_with_object({}) do |(k, v), p|
        if /^\$\(([^)]+)\)$/ =~ v
          p[k] = record[$1] # can be ::String, ::Numeric, etc.
        else
          p[k] = v ? v.gsub(/\$\(([^)]+)\)/) { record[$1] } : nil # ::String
        end
      end
      t = params["time"] || time
      t = Time.parse(t) if t.is_a?(::String)
      t = t.to_f * 1000 if t.is_a?(::Date) or t.is_a?(::Time)
      t = [t / 1000, t, t * 1000].min_by { |_t| (Time.now.to_f * 1000 - _t).abs } # to milliseconds
      t = t.to_i
      params["time"] = t

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
