require 'yaml'
require 'erb'
require 'ostruct'
require_relative '../errors/poker_calendar_errors'

module PokerCalendar
  module Config
    class Environment
      class << self
        def load_settings(env = nil)
          env ||= ENV['POKER_CALENDAR_ENV'] || 'development'
          
          config_file = File.join(File.dirname(__FILE__), '../../../config/settings.yml')
          unless File.exist?(config_file)
            raise ConfigurationError, "Configuration file not found: #{config_file}"
          end

          raw_config = File.read(config_file)
          erb_config = ERB.new(raw_config).result
          all_settings = YAML.safe_load(erb_config, aliases: true)
          
          settings = all_settings[env.to_s]
          unless settings
            raise ConfigurationError, "Configuration not found for environment: #{env}"
          end

          validate_settings(settings)
          OpenStruct.new(deep_symbolize_keys(settings))
        end

        private

        def validate_settings(settings)
          required_keys = %w[spreadsheet_key data_dir base_url]
          missing_keys = required_keys.select { |key| settings[key].nil? || settings[key].empty? }
          
          if missing_keys.any?
            raise ConfigurationError, "Missing required configuration keys: #{missing_keys.join(', ')}"
          end
        end

        def deep_symbolize_keys(hash)
          hash.each_with_object({}) do |(key, value), result|
            new_key = key.to_sym
            new_value = value.is_a?(Hash) ? deep_symbolize_keys(value) : value
            result[new_key] = new_value
          end
        end
      end
    end
  end
end
