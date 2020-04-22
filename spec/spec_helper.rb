# frozen_string_literal: true

SPEC_ROOT = __dir__
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

Dir[File.join(SPEC_ROOT, 'specs', 'shared', '**', '*.rb')].sort.each { |path| require path }

RSpec.configure do |config|
  config.color = true

  config.expect_with :rspec do |expectations|
    expectations.max_formatted_output_length = 1_000_000
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end
