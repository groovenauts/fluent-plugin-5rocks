# fluent-plugin-5rocks

[Fluentd](http://fluentd.org) output plugin to insert data into [5rocks](https://www.5rocks.io/) database.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'fluent-plugin-5rocks'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install fluent-plugin-5rocks

## Configuration

```apache
<match dummy>
  type 5rocks

  app_id xxxxxxxxxxxxxxxx
  app_key XXXXXXXXXXXXXXXXX

  <field>
    type custom
    name test_from_plugin
    category cat_1
    p1 test_p_1
    p2 test_p_2
    user_id test_user
    uv1 $(fld_s)
    uv2 $(fld_t)
    <values>
      abc $(fld_i)
    </values>
  </field>
</match>
```

`$(xxx)` expression is provided to load a field data from a fluentd record.

## Contributing

1. Fork it ( https://github.com/groovenauts/fluent-plugin-5rocks/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
