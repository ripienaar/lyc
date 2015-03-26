require 'pp'
require 'lyc'

class Deployment
  include LYC

  property :repo,         :validation => String
  property :listen_port,  :validation => /^\d+$/
  property :environment,  :validation => Hash

  attr_accessor :environments

  def initialize
    @environments = []
  end

  # a custom loader is needed since environment names are dynamic
  # and we will not just take arbitrary keys out of yaml, so this
  # sets any known property and then create new environment children
  # for each environment as they are found
  def load_data(data)
    data.keys.each do |key|
      if include?(key)
        self[key] = data[key]
      else
        env = DeploymentEnvironment.new
        env.name = key.to_s
        env.load_data(data[key])

        environments << key.to_s

        # register a child LYC to establish override hierarchy
        register_child(env, key)
      end
    end
  end
end

class DeploymentEnvironment
  include LYC

  property :environment,
           :merge_with_parent => true,
           :override_parent => false,
           :default => {},
           :validation => Hash

  property :name,
           :validation => String

  property :db_host,
           :validation => String

  property :listen_port,
           :validation => /^\d+$/,
           :override_parent => true

  def db_host_validator!(value)
    require 'resolv'
    Resolv.getaddress(value)
  rescue
    raise("db_host DNS validation of host `%s` failed: %s" % [value, $!.to_s])
  end
end

class ConfigRoot
  include LYC

  property :deployment,
           :type => :child,
           :default => Deployment.new
end

config = ConfigRoot.new
config.load_from_yaml("example/config.yaml")

deployment = config.deployment

puts "Deployment Defaults:"
puts "         repo: %s" % deployment.repo
puts "  listen_port: %s" % deployment.listen_port
puts "  environment: %s" % deployment.environment.inspect
puts
puts "Found the following environments: %s" % deployment.environments.join(", ")

puts

deployment.environments.each do |environment|
  puts "Settings for %s environment:" % environment
  puts
  puts "  listen_port: %s" % deployment[environment].listen_port
  puts "      db_host: %s" % deployment[environment].db_host
  puts "  environment: %s" % deployment[environment].environment.inspect
  puts
end
