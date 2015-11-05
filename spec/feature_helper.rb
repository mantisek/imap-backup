require 'spec_helper'
require 'rake'

spec_path = File.dirname(__FILE__)

Rake.application.rake_require 'tasks/test'

support_glob = File.join(spec_path, 'features', 'support', '**', '*.rb')
Dir[support_glob].each { |f| require f }
