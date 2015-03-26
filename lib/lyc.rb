require 'yaml'
require 'lyc/validators'
require 'deep_merge'

module LYC
  module ClassMethods
    DEFAULT_CONFIG = {
      :default => nil,
      :merge_with_default => false,   # if default is a hash merge the supplied value with default
      :merge_with_parent => false,    # if there's a parent, merge arrays and hashes with parent
      :override_parent => true,       # if there's a parent, always take this one
      :validation => nil,
      :type => nil
    }

    def property(name, args={})
      name = name.to_s

      raise("Already have a property %s" % name) if lyc_config.include?(name)
      raise("Properties can't be both :merge_with_parent and :override_parent") if (args[:override_parent] && args[:merge_with_parent])

      config = DEFAULT_CONFIG.merge(args)

      if config[:type] == :hash
        config[:validation] = Hash unless config[:validation]
        config[:default] = {} if config[:default].nil?
        raise("Properties of type :hash can only have defaults of type Hash") if !config[:default].is_a?(Hash)
      end

      if config[:type] == :array
        config[:validation] = Array unless config[:validation]
        config[:default] = [] if config[:default].nil?
        raise("Properties of type :array can only have defaults of type Array") if !config[:default].is_a?(Array)
      end

      lyc_config[name] = config
    end

    def lyc_config
      return @lyc_config_values if @lyc_config_values

      @lyc_config_values = {}

      @lyc_config_values["__parent"] = ClassMethods::DEFAULT_CONFIG.merge(:validation => LYC)
      @lyc_config_values["__children"] = ClassMethods::DEFAULT_CONFIG.merge(:default => [], :type => :array, :validation => Array)

      @lyc_config_values
    end

    def lyc_config_default_value(property)
      property = property.to_s

      raise("Unknown property %s" % property) unless lyc_config.include?(property)

      lyc_config[property][:default]
    end
  end

  def self.included(base)
    base.extend ClassMethods
  end

  def each
    lyc_config.keys.reject{|k| k =~ /^__/}.each do |key|
      yield [key, lyc_resolve_value(key)]
    end
  end

  def child?(property)
    lyc_config[property.to_s][:type] == :child
  end

  def register_child(child, name=nil)
    raise("Child objects must be of type LYC") unless child.is_a?(LYC)

    self["__children"] << child

    if name
      self.class.property(name, :type => :child, :validation => LYC)
      self[name] = child
    end

    child.set_parent(self)

    child
  end

  def set_parent(parent)
    return unless parent

    raise("Parent objects must be of type LYC") unless parent.is_a?(LYC)

    lyc_update_property("__parent", parent)
  end

  def default_property_value(property)
    self.class.lyc_config_default_value(property)
  end

  def lyc_values
    return @lyc_values if @lyc_values

    @lyc_values = {}

    lyc_config.each_pair do |property, args|
      lyc_update_property(property, default_property_value(property), false, false)
    end

    @lyc_values
  end

  def lyc_config
    self.class.lyc_config
  end

  def include?(property)
    lyc_config.include?(property.to_s)
  end

  def lyc_update_property(property, value, munge=true, validate=true)
    property = property.to_s

    raise("Unknown property %s" % property) unless include?(property)

    validator = ("%s_validator!" % property).intern
    munger = ("%s_munger!" % property).intern

    unless value.is_a?(LYC)
      value = send(munger, Marshal.load(Marshal.dump(value))) if munge
      send(validator, value) if validate
    end

    lyc_values[property] = value

    if lyc_config[property][:merge_with_default]
      v = Marshal.load(Marshal.dump(value))
      d = Marshal.load(Marshal.dump(lyc_config[property][:default]))
      lyc_values[property] = d.deep_merge(v)
    end

    lyc_values[property]
  end

  def [](property)
    lyc_resolve_value(property.to_s)
  end

  def []=(property, value)
    lyc_update_property(property.to_s, value)
  end

  def load_from_yaml(yaml_file)
    require 'yaml'
    data = YAML.load(File.read(yaml_file))
    load_data(data)
  end

  def load_data(data)
    data.keys.each do |key|
      if include?(key)
        if child?(key)
          self[key].load_data(data[key])
        else
          self[key] = data[key]
        end
      else
        raise("While loading data in `%s`, found `%s` that is not known" % [self.class, key])
      end
    end
  end

  def lyc_validate_property(property, value)
    raise("Unknown property `%s` in `%s`" % [property, self.class]) unless include?(property)

    validation = lyc_config[property.to_s][:validation]
    type = lyc_config[property.to_s][:type]
    default = lyc_config[property.to_s][:default]

    Validators::validate!(property, validation, value, type, default)
  end

  def parent
    lyc_values["__parent"]
  end

  def lyc_merge_array(property)
    lyc_values[property] + parent[property]
  end

  def lyc_merge_hash(property)
    own = Marshal.load(Marshal.dump(lyc_values[property]))
    parents = Marshal.load(Marshal.dump(parent[property]))

    own.deep_merge(parents)
  end

  def lyc_resolve_value(property)
    raise("Unknown property %s" % property) unless include?(property)

    property_config = lyc_config[property]

    # dont mess around with children
    if property_config[:type] == :child
      return lyc_values[property]
    end

    return lyc_values[property] unless parent

    # parent does not have this thing, no overriding / merging can happen
    return lyc_values[property] if !parent.include?(property)

    # straight up override, just take first to be found
    if property_config[:override_parent]
      if lyc_values[property].nil?
        return parent[property]
      else
        return lyc_values[property]
      end
    end

    # no overrides are configured, return our value unless we're merging
    return lyc_values[property] if !property_config[:merge_with_parent]

    # all thats left are merges
    if (property_config[:type] == :array || property_config[:validation] == Array)
      lyc_merge_array(property)
    elsif (property_config[:type] == :hash || property_config[:validation] == Hash)
      lyc_merge_hash(property)
    else
      raise("While resolving `%s` in `%s`: Can only merge array or hash type properties" % [property, self.class])
    end
  end

  def method_missing(method, *args)
    method = method.to_s

    if include?(method)
      return lyc_resolve_value(method)

    elsif method =~ /^(has_)*(.+?)\?$/
      return include?(method)

    elsif method =~ /^(.+)=$/
      return lyc_update_property($1, args.first) if include?($1)

    elsif method =~ /^(.+)_munger!/
      return args.first

    elsif method =~ /^(.+)_validator!/
      return lyc_validate_property($1, args.first)
    end

    raise(NameError, "undefined local variable or method `%s' in `%s'" % [method, self.class])
  end
end
