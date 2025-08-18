# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Ruby application that scrapes poker tournament information from pokerguild.jp, processes it using OpenAI API, and uploads the results to Google Spreadsheets. The main workflow involves:

1. **TournamentScraper**: Fetches daily tournament data from pokerguild.jp using curl
2. **TournamentParser**: Processes the scraped data and converts it to CSV format  
3. **GoogleSpreadsheetUploader**: Uploads CSV data to Google Spreadsheets

## Core Commands

- **Run the application**: `ruby bin/update_calendar.rb`
- **Install dependencies**: `bundle install`

## Architecture

### Main Components

- `bin/update_calendar.rb`: Main entry point that orchestrates the entire process
- `lib/poker_calendar/tournament_scraper.rb`: Handles web scraping from pokerguild.jp
- `lib/poker_calendar/tournament_parser.rb`: Converts scraped HTML to structured CSV data
- `lib/poker_calendar/google_spreadsheet_uploader.rb`: Manages Google Sheets API integration
- `lib/poker_calendar/loggable.rb`: Shared logging functionality across all classes
- `config/settings.rb`: Configuration constants including spreadsheet keys and file paths

### Data Flow

1. Scraper fetches daily tournament HTML and individual tournament pages
2. Tournament info is sent to OpenAI API for structured data extraction (JSON format)
3. Parser converts OpenAI responses to CSV with specific columns (shop_name, address, area, title, etc.)
4. Uploader clears existing spreadsheet data and uploads new CSV content

### Key Dependencies

- `ruby-openai`: For AI-powered tournament data extraction
- `google_drive`: For Google Sheets API integration  
- `csv`: For data processing

### File Naming Conventions

- Raw HTML files: `pg-{date}--tourneys-{id}.txt`
- OpenAI response files: `res-pg-{date}--tourneys-{id}.json`
- CSV output files: `tourney_info_{date}.csv`

### Configuration Requirements

- `.env` file with OpenAI API token
- `config.json` with Google Service Account credentials
- Target Google Spreadsheet key defined in `config/settings.rb`

## Data Storage

- `data/` directory contains all scraped HTML files, AI responses, and generated CSV files
- Files are organized by date and tournament ID
- The application automatically deletes `test.log` on each run