What?
=====

A layered configuration library for Ruby.

It's early days and a work in progress and you certainly do not want to use this till I at least
add some tests.

Example?
--------

Below example will describe a hypothetical deployment of some software.

It supports 2 environmnets - ```production``` and ```development``` - and has a number
of properties.

In this case we have a top level ```deployment``` key that sets a bunch of defaults to
use, but then each specific environment can override those.  Should the environment override
one - like ```listen_port``` - then the environment specific config would return that. In
others like with ```environment``` we want the child layers to be able to override environment
values as well as contribute their own.


```
:deployment:
  :repo: your_app
  :listen_port: 80
  :environment:
    SESSION_SECRET: unset
    DB_PASSWORD: supersecret

  :production:
    :db_host: db.example.net
    :environment:
      SESSION_SECRET: rahDexaemeneekochebe
      DB_PASSWORD: bahngeecaiTeejiehera
      ENVIRONMENT: production

  :development:
    :listen_port: 9292
    :db_host: db.dev.example.net
```

It provides a ruby class for creating these layered configuration formats and unlike
your typical configuration format the values are validated and it will only accept keys
that's been declared as being supported which helps avoid many of the things YAML configurations
are bad at like hard to find simple typos.

To create this configuration hierarchy you'd need 3 classes. The exaple has ```ConfigRoot```,
```Deployment``` and ```DeploymentEnvironment```.  Each environment is a instance of ```DeploymentEnvironment```.

Once loaded you can interact with the config tree:

```
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
```

which for the above YAML file prints:

```
Deployment Defaults:
         repo: your_app
  listen_port: 80
  environment: {"SESSION_SECRET"=>"unset", "DB_PASSWORD"=>"supersecret"}

Found the following environments: production, development

Settings for production environment:

  listen_port: 80
      db_host: db.example.net
  environment: {"SESSION_SECRET"=>"rahDexaemeneekochebe", "DB_PASSWORD"=>"bahngeecaiTeejiehera", "ENVIRONMENT"=>"production"}

Settings for development environment:

  listen_port: 9292
      db_host: db.dev.example.net
  environment: {"SESSION_SECRET"=>"unset", "DB_PASSWORD"=>"supersecret"}
```

Custom and builtin validators are supported, in the example the hostnames for ```db_host``` gets
validated with a custom validator to be DNS resolvable.

The full example is in the ```example``` directory.
