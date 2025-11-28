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

      def self.delete_edits_if_exists(app_id:, token:)
        edits_id, etag = self.get_edits(app_id: app_id, token: token)
        return nil if edits_id.nil? || etag.nil? # Do nothing if edits do not exist

        edits_path = "api/appstore/v1/applications/#{app_id}/edits"
        delete_edits_response = api_client.delete("#{edits_path}/#{edits_id}") do |request|
          request.headers['Authorization'] = "Bearer #{token}"
          request.headers['If-Match'] = etag
        end

        raise StandardError, delete_edits_response.body unless delete_edits_response.success?
      end

      def self.get_edits(app_id:, token:)
        edits_path = "api/appstore/v1/applications/#{app_id}/edits"
        edits_response = api_client.get(edits_path) do |request|
          request.headers['Authorization'] = "Bearer #{token}"
        end
        raise StandardError, edits_response.body unless edits_response.success?

        edits_id = edits_response.body[:id]
        etag = edits_response.headers['Etag']

        return edits_id, etag
      end

      def self.upload_apk(local_apk_path:, app_id:, edit_id:, token:)
        upload_apk_path = "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/apks/upload"
        upload_apk_response = api_client.post(upload_apk_path) do |request|
          request.body = Faraday::UploadIO.new(local_apk_path, 'application/vnd.android.package-archive')
          request.headers['Content-Length'] = request.body.stat.size.to_s
          request.headers['Content-Type'] = 'application/vnd.android.package-archive'
          request.headers['Authorization'] = "Bearer #{token}"
        end
        raise StandardError, upload_apk_response.body unless upload_apk_response.success?

        {
          version_code: upload_apk_response.body[:versionCode],
          apk_id: upload_apk_response.body[:id]
        }
      end

      def self.replace_apks(apk_paths:, app_id:, edit_id:, token:)
        # Get existing APKs in the edit
        get_apks_path = "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/apks"
        get_apks_response = api_client.get(get_apks_path) do |request|
          request.headers['Authorization'] = "Bearer #{token}"
        end
        raise StandardError, get_apks_response.body unless get_apks_response.success?

        existing_apks = get_apks_response.body
        raise StandardError, 'No existing APKs found in edit' if existing_apks.empty?

        version_codes = []
        apk_results = []

        apk_paths.each_with_index do |apk_path, index|
          if index < existing_apks.length
            # Replace existing APK at the specified index
            apk_id = existing_apks[index][:id]
            raise StandardError, "apk_id is nil for index #{index}" if apk_id.nil?

            # Get ETag for the specific APK
            get_etag_path = "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/apks/#{apk_id}"
            etag_response = api_client.get(get_etag_path) do |request|
              request.headers['Authorization'] = "Bearer #{token}"
            end
            raise StandardError, etag_response.body unless etag_response.success?

            etag = etag_response.headers['Etag']

            # Replace the APK
            replace_apk_path = "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/apks/#{apk_id}/replace"
            replace_apk_response = api_client.put(replace_apk_path) do |request|
              request.body = Faraday::UploadIO.new(apk_path, 'application/vnd.android.package-archive')
              request.headers['Content-Length'] = request.body.stat.size.to_s
              request.headers['Content-Type'] = 'application/vnd.android.package-archive'
              request.headers['Authorization'] = "Bearer #{token}"
              request.headers['If-Match'] = etag
            end
            raise StandardError, replace_apk_response.body unless replace_apk_response.success?

            version_code = replace_apk_response.body[:versionCode]
            version_codes << version_code
            apk_results << { version_code: version_code, apk_id: apk_id }
          else
            # Upload new APK if there are more APK paths than existing APKs
            result = upload_apk(
              local_apk_path: apk_path,
              app_id: app_id,
              edit_id: edit_id,
              token: token
            )
            version_codes << result[:version_code]
            apk_results << result
          end
        end

        # Delete remaining APKs if there are more existing APKs than specified APK paths
        if existing_apks.length > apk_paths.length
          remaining_apks = existing_apks[apk_paths.length..]
          UI.message("Deleting #{remaining_apks.length} remaining APK(s)...")

          remaining_apks.each_with_index do |apk, index|
            delete_apk(
              app_id: app_id,
              edit_id: edit_id,
              apk_id: apk[:id],
              token: token
            )
            UI.message("Deleted APK ID: #{apk[:id]} (position #{apk_paths.length + index + 1})")
          end
        end

        apk_results
      end

      def self.delete_apk(app_id:, edit_id:, apk_id:, token:)
        # Get ETag for the APK to be deleted
        get_etag_path = "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/apks/#{apk_id}"
        etag_response = api_client.get(get_etag_path) do |request|
          request.headers['Authorization'] = "Bearer #{token}"
        end
        raise StandardError, etag_response.body unless etag_response.success?

        etag = etag_response.headers['Etag']

        # Delete the APK
        delete_apk_path = "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/apks/#{apk_id}"
        delete_apk_response = api_client.delete(delete_apk_path) do |request|
          request.headers['Authorization'] = "Bearer #{token}"
          request.headers['If-Match'] = etag
        end
        raise StandardError, delete_apk_response.body unless delete_apk_response.success?

        UI.message("Successfully deleted APK #{apk_id}")
      end

      def self.update_listings_for_multiple_apks(app_id:, edit_id:, token:, version_codes:, skip_upload_changelogs:, metadata_path:)
        return if skip_upload_changelogs

        UI.message("Updating listings for #{version_codes.length} version codes: #{version_codes.join(', ')}")

        # Get listings once with ETag
        listings_path = "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/listings"
        listings_response = api_client.get(listings_path) do |request|
          request.headers['Authorization'] = "Bearer #{token}"
        end
        raise StandardError, listings_response.body unless listings_response.success?

        # Process each language once
        listings_response.body[:listings].each do |lang, listing|
          # Get fresh ETag for each language update to avoid conflicts
          etag_response = api_client.get(listings_path) do |request|
            request.headers['Authorization'] = "Bearer #{token}"
          end
          raise StandardError, etag_response.body unless etag_response.success?

          etag = etag_response.headers['Etag']

          # Find the best changelog for multiple version codes
          recent_changes = find_changelog_for_multiple_version_codes(
            language: listing[:language],
            version_codes: version_codes,
            metadata_path: metadata_path
          )
          listing[:recentChanges] = recent_changes

          # Update listings once per language
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

      def self.upload_image(app_id:, edit_id:, language:, image_type:, image_path:, token:)
        upload_path = "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/listings/#{language}/#{image_type}/upload"
        upload_response = api_client.post(upload_path) do |request|
          request.body = Faraday::UploadIO.new(image_path, 'image/png')
          request.headers['Content-Type'] = 'image/png'
          request.headers['Authorization'] = "Bearer #{token}"
        end
        raise StandardError, upload_response.body unless upload_response.success?

        upload_response.body[:id]
      end

      def self.get_images(app_id:, edit_id:, language:, image_type:, token:)
        images_path = "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/listings/#{language}/#{image_type}"
        images_response = api_client.get(images_path) do |request|
          request.headers['Authorization'] = "Bearer #{token}"
        end
        raise StandardError, images_response.body unless images_response.success?

        images_response.body
      end

      def self.delete_all_images(app_id:, edit_id:, language:, image_type:, token:)
        images_path = "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/listings/#{language}/#{image_type}"
        etag_response = api_client.get(images_path) do |request|
          request.headers['Authorization'] = "Bearer #{token}"
        end
        raise StandardError, etag_response.body unless etag_response.success?

        etag = etag_response.headers['Etag']
        delete_response = api_client.delete(images_path) do |request|
          request.headers['Authorization'] = "Bearer #{token}"
          request.headers['If-Match'] = etag
        end
        raise StandardError, delete_response.body unless delete_response.success?

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

      def self.find_changelog_for_multiple_version_codes(language:, version_codes:, metadata_path:)
        # Use the highest version code's changelog (same as Fastlane's approach)
        max_version_code = version_codes.max
        UI.message("Using changelog for highest version code: #{max_version_code}")
        find_changelog(
          language: language,
          version_code: max_version_code,
          skip_upload_changelogs: false,
          metadata_path: metadata_path
        )
      end

      def self.find_changelog(language:, version_code:, skip_upload_changelogs:, metadata_path:)
        # The Amazon appstore requires you to enter changelogs before reviewing.
        # Therefore, if there is no metadata, hyphen text is returned.
        changelog_text = '-'
        return changelog_text if skip_upload_changelogs

        path = File.join(metadata_path, language, 'changelogs', "#{version_code}.txt")
        if File.exist?(path) && !File.empty?(path)
          UI.message("Updating changelog for '#{version_code}' and language '#{language}'...")
          changelog_text = File.read(path, encoding: 'UTF-8')
        else
          default_changelog_path = File.join(metadata_path, language, 'changelogs', 'default.txt')
          if File.exist?(default_changelog_path) && !File.empty?(default_changelog_path)
            UI.message("Updating changelog for '#{version_code}' and language '#{language}' to default changelog...")
            changelog_text = File.read(default_changelog_path, encoding: 'UTF-8')
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
