require_relative 'config/environment'
require_relative 'utils/logger'
require_relative 'utils/retry_handler'
require_relative 'clients/http_client'
require_relative 'clients/openai_client'
require_relative 'clients/google_drive_client'
require_relative 'repositories/file_repository'
require_relative 'parsers/html_parser'
require_relative 'parsers/ai_analyzer'
require_relative 'services/tournament_scraper'
require_relative 'services/tournament_parser'
require_relative 'services/spreadsheet_uploader'
require_relative 'errors/poker_calendar_errors'

module PokerCalendar
  class Container
    def initialize(env = nil)
      @settings = Config::Environment.load_settings(env)
      @logger = create_logger
      @instances = {}
    end

    def tournament_scraper
      @instances[:tournament_scraper] ||= Services::TournamentScraper.new(
        http_client: http_client,
        file_repository: file_repository,
        ai_analyzer: ai_analyzer,
        html_parser: html_parser,
        logger: @logger,
        base_url: @settings.base_url
      )
    end

    def tournament_parser
      @instances[:tournament_parser] ||= Services::TournamentParser.new(
        file_repository: file_repository,
        tournament_scraper: tournament_scraper,
        logger: @logger
      )
    end

    def spreadsheet_uploader
      @instances[:spreadsheet_uploader] ||= Services::SpreadsheetUploader.new(
        google_drive_client: google_drive_client,
        file_repository: file_repository,
        logger: @logger
      )
    end

    def settings
      @settings
    end

    def logger
      @logger
    end

    private

    def create_logger
      Utils::StructuredLogger.new(STDOUT, Logger::INFO)
    end

    def http_client
      @instances[:http_client] ||= Clients::HttpClient.new(
        logger: @logger,
        request_delay: @settings.scraping.request_delay,
        max_retries: @settings.scraping.max_retries
      )
    end

    def openai_client
      @instances[:openai_client] ||= begin
        access_token = read_openai_token
        Clients::OpenaiClient.new(
          access_token: access_token,
          model: @settings.openai.model,
          temperature: @settings.openai.temperature,
          rate_limit_delay: @settings.openai.rate_limit_delay,
          logger: @logger
        )
      end
    end

    def google_drive_client
      @instances[:google_drive_client] ||= Clients::GoogleDriveClient.new(
        config_path: @settings.config_path,
        logger: @logger
      )
    end

    def file_repository
      @instances[:file_repository] ||= Repositories::FileRepository.new(
        data_dir: @settings.data_dir,
        logger: @logger
      )
    end

    def html_parser
      @instances[:html_parser] ||= Parsers::HtmlParser.new(logger: @logger)
    end

    def ai_analyzer
      @instances[:ai_analyzer] ||= Parsers::AiAnalyzer.new(
        openai_client: openai_client,
        logger: @logger
      )
    end

    def read_openai_token
      token_file = '.env'
      unless File.exist?(token_file)
        raise ConfigurationError, "OpenAI token file not found: #{token_file}"
      end
      
      File.read(token_file).strip
    end
  end
end
