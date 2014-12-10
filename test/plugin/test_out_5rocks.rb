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
      "values[key_a]" => "val_a",
      "values[key_b]" => "$(data_key)",
    }
    assert_equal expected, d.instance.field_map
  end

  def test_format
    d = create_driver

    time = Time.parse("2014-12-08 18:20:30 UTC").to_i
    d.emit({"data_key" => 1}, time)
    d.emit({"data_key" => 2}, time)

    d.expect_format ["test", time, {"data_key" => 1}].to_msgpack
    d.expect_format ["test", time, {"data_key" => 2}].to_msgpack

    stub_request(:post, 'https://server.api.5rocks.io/sev/1/test_app_id').to_return(:status => [201, "Created"])
    d.run
  end

  def test_write
    d = create_driver

    time = Time.parse("2014-12-08 18:20:30 UTC").to_i
    d.emit({"data_key" => 7}, time)
    d.emit({"data_key" => 5}, time)

    stub_request(:post, 'https://server.api.5rocks.io/sev/1/test_app_id').to_return(:status => [201, "Created"])
    params = d.run
    expected = [
      {
        "app_key" => "test_app_key", "type" => "custom", "name" => "test_from_plugin", "category" => "cat_a",
        "values[key_a]" => "val_a", "values[key_b]"=>7
      },
      {
        "app_key" => "test_app_key", "type" => "custom", "name" => "test_from_plugin", "category" => "cat_a",
        "values[key_a]" => "val_a", "values[key_b]"=>5
      }
    ]
    assert_equal expected, params
  end
end
