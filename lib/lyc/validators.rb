module LYC
  module Validators
    def self.validate!(property, validation, value, type, default)
      return true if validation.nil?

      # if the value is the default we dont validate it allowing nil
      # defaults but validation only on assignment of non default value
      return true if value == default

      type_property_validator(property, type, value)
      nil_value_validator(property, validation, value)

      if validation.is_a?(Symbol)
        symbol_validation_validator(property, validation, value)
      elsif validation.is_a?(Array)
        array_validation_validator(property, validation, value)
      elsif validation.is_a?(Regexp)
        regexp_validation_validator(property, validation, value)
      elsif validation.is_a?(Proc)
        proc_validation_validator(property, validation, value)
      else
        raise("%s is a %s should be a %s" % [property, value.class, validation]) unless value.is_a?(validation)
      end

      true
    end

    def self.nil_value_validator(property, validation, value)
      raise("%s should be %s" % [property, validation]) if value.nil? && !validation.nil?
    end

    def self.type_property_validator(property, type, value)
      if type == :hash
        raise("%s should be a Hash" % property) unless value.is_a?(Hash)
      elsif type == :array
        raise("%s should be an Array" % property) unless value.is_a?(Array)
      end
    end

    def self.array_validation_validator(property, validation, value)
      raise "%s should be one of %s" % [property, validation.join(", ")] unless validation.include?(value)
    end

    def self.regexp_validation_validator(property, validation, value)
      raise("%s should match %s" % [property, validation]) unless value.to_s.match(validation)
    end

    def self.proc_validation_validator(property, validation, value)
      raise("%s does not validate against lambda" % property) unless validation.call(value)
    end

    def self.symbol_validation_validator(property, validation, value)
      validator = ("%s_type_validator" % validation).intern
      if Validators.respond_to?(validator)
        Validators.send(validator, property, value)
      else
        raise("Don't know how to validate %s using %s" % [property, validation])
      end
    end

    def self.ipv6_type_validator(property, value)
      begin
        require 'ipaddr'
        ip = IPAddr.new(value)
        raise("%s should be a valid IPv6 address" % property) unless ip.ipv6?
      rescue
        raise("%s should be a valid IPv6 address" % property)
      end
    end

    def self.ipv4_type_validator(property, value)
      begin
        require 'ipaddr'
        ip = IPAddr.new(value)
        raise("%s should be a valid IPv4 address" % property) unless ip.ipv4?
      rescue
        raise("%s should be a valid IPv4 address" % property)
      end
    end

    def self.boolean_type_validator(property, value)
      raise("%s should be a boolean" % property) unless [TrueClass, FalseClass].include?(value.class)
    end
  end
end
