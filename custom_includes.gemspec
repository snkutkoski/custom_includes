# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'custom_includes/version'

Gem::Specification.new do |spec|
  spec.name          = "custom_includes"
  spec.version       = CustomIncludes::VERSION
  spec.authors       = ["Steven Kutkoski"]
  spec.email         = ["skutkoski@selectrehab.com"]

  spec.summary       = %q{Adds a custom includes method to ActiveRecord for including remote associations}
  spec.description   = %q{Adds a custom includes method to ActiveRecord for including remote associations}
  spec.homepage      = "TODO: Put your gem's website or public repo URL here."

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'activerecord', '>= 4.2'
  spec.add_dependency 'activesupport', '>= 4.2'

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency 'byebug'
  spec.add_development_dependency 'sqlite3', '~> 1.3', '>= 1.3.11'
  spec.add_development_dependency 'factory_girl', '~> 4.7'
end
