require 'fileutils'
require 'json'

module Fastlane
  module Actions
    class OneskyDownloadItunesAction < Action
      def self.run(params)
        containing = Helper.fastlane_enabled? ? FastlaneCore::FastlaneFolder.path : '.'
        dir = params[:metadata_path] || File.join(containing, 'metadata')
        itunes_locale = params[:itunes_locale]
        onesky_locale = params[:onesky_locale] || itunes_locale

        Actions.verify_gem!('onesky-ruby')
        require 'onesky'

        client = ::Onesky::Client.new(params[:public_key], params[:secret_key])
        project = client.project(params[:project_id])

        UI.message "Downloading app metadata for #{onesky_locale}"
        resp = project.export_app_description(locale: onesky_locale)

        if resp.length == 0
          UI.message "No metadata found for #{onesky_locale}"
          return
        end
        data = JSON.parse(resp)
        metadata = data["data"]

        write_metadata(value: metadata["APP_NAME"], filename: "name.txt", metadata_path: dir, locale: itunes_locale)
        write_metadata(value: metadata["APP_DESCRIPTION"], filename: "description.txt", metadata_path: dir, locale: itunes_locale)
        write_metadata(value: metadata["APP_VERSION_DESCRIPTION"], filename: "release_notes.txt", metadata_path: dir, locale: itunes_locale)

        keyword_list = metadata["APP_KEYWORD"].values.join(",")
        if keyword_list.length > 100
          length = keyword_list.length
          removed = []
          sublist = metadata["APP_KEYWORD"].values.dup
          while keyword_list.length > 100
            removed << sublist.pop
            keyword_list = sublist.join(",")
          end
          skipped = []
          metadata["APP_KEYWORD"].each do |k,v|
            if removed.include? v
              skipped << "#{v} (#{k})"
            end
          end
          UI.important("Your keywords are #{length} characters long, but can't be more than 100.")
          UI.important("Removed #{skipped.join(", ")}. Your keywords are now #{keyword_list.length} characters. '#{keyword_list}'")
        end
        write_metadata(value: keyword_list, filename: "keywords.txt", metadata_path: dir, locale: itunes_locale)

        UI.success "Saved app metadata for #{itunes_locale}"
      end

      def self.description
        'Download Fastlane App Store metadata translations from a OneSky iTunes App Store project'
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
          FastlaneCore::ConfigItem.new(key: :metadata_path,
                                       description: 'Path to the folder containing the metadata files',
                                       is_string: true,
                                       optional: true,
                                       verify_block: proc do |value|
                                         raise "Couldn't find metadata directory at path '#{value}'".red unless File.directory?(value)
                                       end),
          FastlaneCore::ConfigItem.new(key: :onesky_locale,
                                       description: 'Locale of the metadata to download from OneSky',
                                       is_string: true,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :itunes_locale,
                                       description: 'Locale of the metadata in iTunes',
                                       is_string: true,
                                       optional: false)
        ]
      end

      def self.is_supported?(platform)
        true
      end


      private

      def self.write_metadata(value:, filename:, metadata_path:, locale:)
        path = File.join(metadata_path, locale, filename)

        FileUtils.mkdir_p(File.dirname(path))

        begin
          File.open(path, 'w') { |file| file.write(value) }
        rescue
          raise "Problem writing app #{File.basename(filename).gsub('_', ' ')} at path '#{path}'".red
        end
      end

    end
  end
end
