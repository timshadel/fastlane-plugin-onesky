require 'json'

module Fastlane
  module Actions
    class OneskyUploadItunesAction < Action
      def self.run(params)
        containing = Helper.fastlane_enabled? ? FastlaneCore::FastlaneFolder.path : '.'
        dir = params[:metadata_path] || File.join(containing, 'metadata')
        locale = params[:itunes_locale]

        UI.message "Loading metadata from #{locale}"
        metadata = {}
        metadata["APP_NAME"] = read_metadata(filename: "name.txt", metadata_path: dir, locale: locale)
        metadata["APP_DESCRIPTION"] = read_metadata(filename: "description.txt", metadata_path: dir, locale: locale)
        metadata["APP_VERSION_DESCRIPTION"] = read_metadata(filename: "release_notes.txt", metadata_path: dir, locale: locale)

        keyword_list = read_metadata(filename: "keywords.txt", metadata_path: dir, locale: locale)
        UI.important("Use commas (,) to separate keywords so that multi-word phrases may be properly translated.") unless keyword_list.include? ","
        keywords = keyword_list.split(',')
        if keywords.length == 1
          UI.message "Found 1 keyword"
        else
          UI.message "Found #{keywords.length} keywords"
        end
        metadata_keywords = {}
        for keyword in keywords
          metadata_keywords[keyword] = keyword
        end
        metadata["APP_KEYWORD"] = metadata_keywords

        Dir.mktmpdir do |dir|
          file = File.join(dir, 'AppDescription.json')
          File.open(file, 'w') { |file| file.write(JSON.dump(metadata)) }
          UI.message "Formatted app metadata for upload"
          Helper::OneskyHelper.upload(public_key: params[:public_key], secret_key: params[:secret_key], project_id: params[:project_id], strings_file_path: file, strings_file_format: 'HIERARCHICAL_JSON', skip_if_in_translation: params[:skip_if_in_translation], onesky_locale: params[:onesky_locale], deprecate_missing: true, metadata: true)
        end
      end

      def self.description
        'Upload Fastlane App Store metadata to a OneSky iTunes App Store project'
      end

      def self.authors
        ['timshadel']
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :public_key,
                                       env_name: 'ONESKY_PUBLIC_KEY',
                                       description: 'Public key for OneSky',
                                       is_string: true,
                                       optional: false,
                                       verify_block: proc do |value|
                                         raise "No Public Key for OneSky given, pass using `public_key: 'token'`".red unless value and !value.empty?
                                       end),
          FastlaneCore::ConfigItem.new(key: :secret_key,
                                       env_name: 'ONESKY_SECRET_KEY',
                                       description: 'Secret Key for OneSky',
                                       is_string: true,
                                       optional: false,
                                       verify_block: proc do |value|
                                         raise "No Secret Key for OneSky given, pass using `secret_key: 'token'`".red unless value and !value.empty?
                                       end),
          FastlaneCore::ConfigItem.new(key: :project_id,
                                       env_name: 'ONESKY_ITUNES_PROJECT_ID',
                                       description: 'Project Id for iTunes metadata',
                                       optional: false,
                                       verify_block: proc do |value|
                                         raise "No project id given, pass using `project_id: 'id'`".red unless value and !value.empty?
                                       end),
          FastlaneCore::ConfigItem.new(key: :skip_if_in_translation,
                                       env_name: 'ONESKY_SKIP_IF_IN_TRANSLATION',
                                       description: 'Should we skip upload if the file is in translation in OneSky?',
                                       is_string: false,
                                       optional: true,
                                       default_value: true),
          FastlaneCore::ConfigItem.new(key: :metadata_path,
                                       description: 'Path to the folder containing the metadata files',
                                       is_string: true,
                                       optional: true,
                                       verify_block: proc do |value|
                                         raise "Couldn't find metadata directory at path '#{value}'".red unless File.directory?(value)
                                       end),
          FastlaneCore::ConfigItem.new(key: :onesky_locale,
                                       description: 'Locale of the metadata to upload to OneSky',
                                       is_string: true,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :itunes_locale,
                                       description: 'Locale of the locale metadata directory for iTunes',
                                       is_string: true,
                                       optional: true,
                                       default_value: 'en-US')
        ]
      end

      def self.is_supported?(platform)
        true
      end


      private

      def self.read_metadata(filename:, metadata_path:, locale: 'en-US')
        path = File.join(metadata_path, locale, filename)
        begin
          File.read(path).chomp
        rescue
          raise "Problem reading app #{File.basename(filename).gsub('_', ' ')} at path '#{path}'".red
        end
      end

    end
  end
end
