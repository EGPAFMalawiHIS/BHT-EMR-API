# frozen_string_literal: true

require 'yaml'

module StreamingSettings
  module_function

  def enabled?
    normalize_env!
    truthy?(ENV['ENABLE_STREAMING'])
  end

  def normalize_env!
    return unless ENV['ENABLE_STREAMING'].to_s.empty?

    config_path = File.expand_path('application.yml', __dir__)
    return unless File.exist?(config_path)

    app_config = YAML.safe_load(File.read(config_path), aliases: true) || {}
    enabled = app_config['ENABLE_STREAMING']
    ENV['ENABLE_STREAMING'] = enabled.to_s unless enabled.nil?
  rescue StandardError
    # Keep boot resilient when application.yml is missing or malformed.
    nil
  end

  def truthy?(value)
    value.to_s.casecmp('true').zero?
  end
end