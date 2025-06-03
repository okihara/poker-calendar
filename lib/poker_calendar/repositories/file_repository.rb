require 'fileutils'
require_relative '../errors/poker_calendar_errors'

module PokerCalendar
  module Repositories
    class FileRepository
      def initialize(data_dir:, logger:)
        @data_dir = data_dir
        @logger = logger
        ensure_data_directory
      end

      def write(filename, content, encoding: 'UTF-8')
        file_path = File.join(@data_dir, filename)
        @logger.debug("Writing file", path: file_path)
        
        File.write(file_path, content, encoding: encoding)
      rescue => e
        @logger.error("Failed to write file", path: file_path, error: e.message)
        raise ScrapingError, "Failed to write file #{file_path}: #{e.message}"
      end

      def read(filename, encoding: 'UTF-8')
        file_path = File.join(@data_dir, filename)
        @logger.debug("Reading file", path: file_path)
        
        unless File.exist?(file_path)
          raise ScrapingError, "File not found: #{file_path}"
        end
        
        File.read(file_path, encoding: encoding)
      rescue => e
        @logger.error("Failed to read file", path: file_path, error: e.message)
        raise ScrapingError, "Failed to read file #{file_path}: #{e.message}"
      end

      def exists?(filename)
        file_path = File.join(@data_dir, filename)
        File.exist?(file_path)
      end

      def delete_if_exists(filename)
        file_path = File.join(@data_dir, filename)
        if File.exist?(file_path)
          File.delete(file_path)
          @logger.info("Deleted file", path: file_path)
        end
      end

      private

      def ensure_data_directory
        FileUtils.mkdir_p(@data_dir) unless Dir.exist?(@data_dir)
      end
    end
  end
end
