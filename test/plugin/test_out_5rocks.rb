require 'helper'
# require 'time'

class FiveRocksOutputTest < Test::Unit::TestCase

  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
    app_id test_app_id
    app_key test_app_key
    <field>
      type custom
      name test_from_plugin
      category cat_a
      p1 prefix_$(data_key)
      <values>
        key_a val_a
        key_b $(data_key)
      </values>
    </field>
  ]

  def create_driver(conf=CONFIG)
    Fluent::Test::BufferedOutputTestDriver.new(Fluent::FiveRocksOutput).configure(conf)
  end

  def e(name, arg = '', attrs = {}, elements = [])
    attrs = attrs.inject({}){ |m, (k, v)| m[k.to_s] = v; m }
    Fluent::Config::Element.new(name, arg, attrs, elements)
  end

  def test_configure
    ### set configurations
    d = create_driver
    ### check configurations
    assert_equal 'https://server.api.5rocks.io/sev/1/test_app_id', d.instance.url
    expected = {
      "app_key" => "test_app_key",
      "type" => "custom",
      "name" => "test_from_plugin",
      "category" => "cat_a",
      "p1" => "prefix_$(data_key)",
      "values[key_a]" => "val_a",
      "values[key_b]" => "$(data_key)",
    }
    assert_equal expected, d.instance.field_map
  end

  def test_format_and_write
    d = create_driver

    time = Time.parse("2014-12-08 18:20:30 UTC").to_i
    d.emit({"data_key" => 7}, time)
    d.emit({"data_key" => 5}, time)

    d.expect_format ["test", time, {"data_key" => 7}].to_msgpack
    d.expect_format ["test", time, {"data_key" => 5}].to_msgpack

    stub_request(:post, 'https://server.api.5rocks.io/sev/1/test_app_id').to_return(:status => [201, "Created"])
    params = d.run
    expected = [
      {
        "app_key" => "test_app_key", "type" => "custom", "name" => "test_from_plugin", "category" => "cat_a",
        "p1" => "prefix_7", "values[key_a]" => "val_a", "values[key_b]" => 7, "time" => (time * 1000).to_i
      },
      {
        "app_key" => "test_app_key", "type" => "custom", "name" => "test_from_plugin", "category" => "cat_a",
        "p1" => "prefix_5", "values[key_a]" => "val_a", "values[key_b]" => 5, "time" => (time * 1000).to_i
      }
    ]
    assert_equal expected, params
  end

  def test_format_and_write_dfferent_time
    times = [
      Time.parse("2014-12-08 18:10:00 UTC"),
      Time.parse("2014-12-08 18:10:01 UTC"),
    ]
    d = create_driver(%[
      app_id test_app_id
      app_key test_app_key
      <field>
        type custom
        name test_from_plugin
        category cat_a
        p1 prefix_$(data_key)
        p2 $(data_key)$(data_key)
        time $(time)
        <values>
          key_a val_a
          key_b $(data_key)
        </values>
      </field>
    ])

    d.emit({"data_key" => 7, "time" => times[0].to_i}, times[1].to_i) # sec
    d.emit({"data_key" => 5, "time" => (times[0].to_f * 1000).to_i}, times[1].to_i) # millisec
    d.emit({"data_key" => 3, "time" => (times[0].to_f * 1000000).to_i}, times[1].to_i) # microsec

    d.expect_format ["test", times[1].to_i, {"data_key" => 7, "time" => times[0].to_i}].to_msgpack
    d.expect_format ["test", times[1].to_i, {"data_key" => 5, "time" => (times[0].to_f * 1000).to_i}].to_msgpack
    d.expect_format ["test", times[1].to_i, {"data_key" => 3, "time" => (times[0].to_f * 1000000).to_i}].to_msgpack

    stub_request(:post, 'https://server.api.5rocks.io/sev/1/test_app_id').to_return(:status => [201, "Created"])
    params = d.run
    expected = [
      {
        "app_key" => "test_app_key", "type" => "custom", "name" => "test_from_plugin", "category" => "cat_a",
        "p1" => "prefix_7", "p2" => "77",
        "values[key_a]" => "val_a", "values[key_b]" => 7, "time" => (times[0].to_f * 1000).to_i
      },
      {
        "app_key" => "test_app_key", "type" => "custom", "name" => "test_from_plugin", "category" => "cat_a",
        "p1" => "prefix_5", "p2" => "55",
        "values[key_a]" => "val_a", "values[key_b]" => 5, "time" => (times[0].to_f * 1000).to_i
      },
      {
        "app_key" => "test_app_key", "type" => "custom", "name" => "test_from_plugin", "category" => "cat_a",
        "p1" => "prefix_3", "p2" => "33",
        "values[key_a]" => "val_a", "values[key_b]" => 3, "time" => (times[0].to_f * 1000).to_i
      },
    ]
    assert_equal expected, params
  end
  
end
