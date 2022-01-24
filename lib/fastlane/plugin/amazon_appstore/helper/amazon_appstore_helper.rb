require 'fastlane_core/ui/ui'
require 'faraday'
require 'faraday_middleware'
require 'json'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class AmazonAppstoreHelper
      BASE_URL = 'https://developer.amazon.com'
      AUTH_URL = 'https://api.amazon.com/auth/o2/token'

      @api_client = nil
      @timeout = nil

      def self.setup(timeout:)
        @timeout = timeout
      end

      def self.token(client_id:, client_secret:)
        grant_type = 'client_credentials'
        scope = 'appstore::apps:readwrite'
        data = {
          grant_type: grant_type,
          client_id: client_id,
          client_secret: client_secret,
          scope: scope
        }
        auth_response = auth_client.post do |request|
          # without escaping
          request.body = JSON.parse(data.to_json)
        end
        raise StandardError, auth_response.body unless auth_response.success?

        auth_response.body[:access_token]
      end

      def self.create_edits(app_id:, token:)
        create_edits_response = api_client.post("api/appstore/v1/applications/#{app_id}/edits") do |request|
          request.headers['Content-Type'] = 'application/x-www-form-urlencoded'
          request.headers['Authorization'] = "Bearer #{token}"
        end
        raise StandardError, create_edits_response.body unless create_edits_response.success?

        create_edits_response.body[:id]
      end

      def self.replace_apk(local_apk_path:, app_id:, edit_id:, token:)
        get_apks_path = "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/apks"
        get_apks_response = api_client.get(get_apks_path) do |request|
          request.headers['Authorization'] = "Bearer #{token}"
        end
        raise StandardError, get_apks_response.body unless get_apks_response.success?

        first_apk = get_apks_response.body[0]
        apk_id = first_apk[:id]
        raise StandardError, 'apk_id is nil' if apk_id.nil?

        get_etag_path = "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/apks/#{apk_id}"
        etag_response = api_client.get(get_etag_path) do |request|
          request.headers['Authorization'] = "Bearer #{token}"
        end
        raise StandardError, etag_response.body unless etag_response.success?

        etag = etag_response.headers['Etag']

        replace_apk_path = "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/apks/#{apk_id}/replace"
        replace_apk_response = api_client.put(replace_apk_path) do |request|
          request.body = Faraday::UploadIO.new(local_apk_path, 'application/vnd.android.package-archive')
          request.headers['Content-Length'] = request.body.stat.size.to_s
          request.headers['Content-Type'] = 'application/vnd.android.package-archive'
          request.headers['Authorization'] = "Bearer #{token}"
          request.headers['If-Match'] = etag
        end
        raise StandardError, replace_apk_response.body unless replace_apk_response.success?

        replace_apk_response.body[:versionCode]
      end

      def self.update_listings(app_id:, edit_id:, token:, version_code:, skip_upload_changelogs:, metadata_path:)
        listings_path = "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/listings"
        listings_response = api_client.get(listings_path) do |request|
          request.headers['Authorization'] = "Bearer #{token}"
        end
        raise StandardError, listings_response.body unless listings_response.success?

        listings_response.body[:listings].each do |lang, listing|
          etag_response = api_client.get(listings_path) do |request|
            request.headers['Authorization'] = "Bearer #{token}"
          end
          raise StandardError, etag_response.body unless etag_response.success?

          etag = etag_response.headers['Etag']

          recent_changes = find_changelog(
            language: listing[:language],
            version_code: version_code,
            skip_upload_changelogs: skip_upload_changelogs,
            metadata_path: metadata_path
          )
          listing[:recentChanges] = recent_changes

          update_listings_path = "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/listings/#{lang}"
          update_listings_response = api_client.put(update_listings_path) do |request|
            request.body = listing.to_json
            request.headers['Authorization'] = "Bearer #{token}"
            request.headers['If-Match'] = etag
          end
          raise StandardError, update_listings_response.body unless update_listings_response.success?
        end
        nil
      end

      def self.commit_edits(app_id:, edit_id:, token:)
        get_etag_path = "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}"
        etag_response = api_client.get(get_etag_path) do |request|
          request.headers['Authorization'] = "Bearer #{token}"
        end
        raise StandardError, etag_response.body unless etag_response.success?

        etag = etag_response.headers['Etag']

        commit_edits_path = "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/commit"
        commit_edits_response = api_client.post(commit_edits_path) do |request|
          request.headers['Authorization'] = "Bearer #{token}"
          request.headers['If-Match'] = etag
        end
        raise StandardError, commit_edits_response.body unless commit_edits_response.success?

        nil
      end

      def self.api_client
        @api_client ||= Faraday.new(url: BASE_URL) do |builder|
          builder.options.open_timeout = @timeout unless @timeout.nil?
          builder.options.timeout = @timeout unless @timeout.nil?
          builder.request(:multipart)
          builder.request(:url_encoded)
          builder.response(:json, parser_options: { symbolize_names: true })
          builder.adapter(Faraday.default_adapter)
        end
      end
      private_class_method :api_client

      def self.auth_client
        Faraday.new(url: AUTH_URL) do |builder|
          builder.options.open_timeout = @timeout unless @timeout.nil?
          builder.options.timeout = @timeout unless @timeout.nil?
          builder.request(:url_encoded)
          builder.response(:json, parser_options: { symbolize_names: true })
          builder.adapter(Faraday.default_adapter)
        end
      end
      private_class_method :auth_client

      def self.find_changelog(language:, version_code:, skip_upload_changelogs:, metadata_path:)
        # The Amazon appstore requires you to enter changelogs before reviewing.
        # Therefore, if there is no metadata, hyphen text is returned.
        changelog_text = '-'
        return changelog_text if skip_upload_changelogs

        path = File.join(metadata_path, language, 'changelogs', "#{version_code}.txt")
        if File.exist?(path) && !File.zero?(path)
          UI.message("Updating changelog for '#{version_code}' and language '#{language}'...")
          changelog_text = File.read(path, encoding: 'UTF-8')
        else
          defalut_changelog_path = File.join(metadata_path, language, 'changelogs', 'default.txt')
          if File.exist?(defalut_changelog_path) && !File.zero?(defalut_changelog_path)
            UI.message("Updating changelog for '#{version_code}' and language '#{language}' to default changelog...")
            changelog_text = File.read(defalut_changelog_path, encoding: 'UTF-8')
          else
            UI.message("Could not find changelog for '#{version_code}' and language '#{language}' at path #{path}...")
          end
        end
        changelog_text
      end
      private_class_method :find_changelog
    end
  end
end
