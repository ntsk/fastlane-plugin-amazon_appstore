require 'fastlane/action'
require_relative '../helper/amazon_appstore_helper'

module Fastlane
  module Actions
    class UploadToAmazonAppstoreAction < Action
      def self.run(params) # rubocop:disable Metrics/PerceivedComplexity
        Helper::AmazonAppstoreHelper.setup(
          timeout: params[:timeout]
        )

        UI.message("Fetching access token...")
        begin
          token = Helper::AmazonAppstoreHelper.token(
            client_id: params[:client_id],
            client_secret: params[:client_secret]
          )
        rescue StandardError => e
          UI.error(e.message)
          UI.abort_with_message!("Failed to get token")
        end
        UI.abort_with_message!("Failed to get token") if token.nil?

        if params[:overwrite_upload]
          if params[:overwrite_upload_mode] == "new"
            UI.message("Deleting existing edits if needed (overwrite_upload: true, overwrite_upload_mode: new)...")
            begin
              Helper::AmazonAppstoreHelper.delete_edits_if_exists(
                app_id: params[:package_name],
                token: token
              )
            rescue StandardError => e
              UI.error(e.message)
              UI.abort_with_message!("Failed to delete edits (overwrite_upload: true, overwrite_upload_mode: new)")
            end
          elsif params[:overwrite_upload_mode] == "reuse"
            UI.message("Retrieving active edit (overwrite_upload: true, overwrite_upload_mode: reuse)...")
            begin
              edit_id, _ = Helper::AmazonAppstoreHelper.get_edits(
                app_id: params[:package_name],
                token: token
              )
            rescue StandardError => e
              UI.error(e.message)
              UI.abort_with_message!("Failed to get edit_id (overwrite_upload: true, overwrite_upload_mode: new)")
            end
            UI.message("No active edit") if edit_id.nil?
          end
        end

        if edit_id.nil?
          UI.message("Creating new edits...")
          begin
            edit_id = Helper::AmazonAppstoreHelper.create_edits(
              app_id: params[:package_name],
              token: token
            )
          rescue StandardError => e
            UI.error(e.message)
            UI.abort_with_message!("Failed to create edits")
          end
          UI.abort_with_message!("Failed to get edit_id") if edit_id.nil?
        end

        apks = []
        apks << params[:apk] if params[:apk]
        apks += params[:apk_paths] if params[:apk_paths]

        if apks.empty?
          UI.abort_with_message!("No APK files provided. Please provide either 'apk' or 'apk_paths' parameter")
        end

        UI.message("Replacing APKs with #{apks.length} file(s)...")
        begin
          apk_results = Helper::AmazonAppstoreHelper.replace_apks(
            apk_paths: apks,
            app_id: params[:package_name],
            edit_id: edit_id,
            token: token
          )
        rescue StandardError => e
          UI.error(e.message)
          UI.abort_with_message!("Failed to replace APKs")
        end
        # Extract version codes and display results
        version_codes = apk_results.map { |result| result[:version_code] }
        apk_results.each_with_index do |result, index|
          UI.message("Successfully processed APK #{index + 1} with version code: #{result[:version_code]}")
        end

        UI.message("Updating release notes...")
        begin
          Helper::AmazonAppstoreHelper.update_listings_for_multiple_apks(
            app_id: params[:package_name],
            edit_id: edit_id,
            token: token,
            version_codes: version_codes,
            skip_upload_changelogs: params[:skip_upload_changelogs],
            metadata_path: params[:metadata_path]
          )
        rescue StandardError => e
          UI.error(e.message)
          UI.abort_with_message!("Failed to update listings")
        end

        if params[:changes_not_sent_for_review]
          UI.success('Successfully finished the upload to Amazon Appstore')
          return
        end

        UI.message("Committing edits...")
        begin
          Helper::AmazonAppstoreHelper.commit_edits(
            app_id: params[:package_name],
            edit_id: edit_id,
            token: token
          )
        rescue StandardError => e
          UI.error(e.message)
          UI.abort_with_message!("Failed to commit edits")
        end

        UI.success('Successfully finished the upload to Amazon Appstore')
      end

      def self.description
        "Upload apps to Amazon Appstore"
      end

      def self.authors
        ["ntsk"]
      end

      def self.return_value
        # nothing
      end

      def self.details
        "Upload apps to Amazon Appstore"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :client_id,
                                       env_name: "AMAZON_APPSTORE_CLIENT_ID",
                                       description: "Your client id",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :client_secret,
                                       env_name: "AMAZON_APPSTORE_CLIENT_SECRET",
                                       description: "Your client secret",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :package_name,
                                       env_name: "AMAZON_APPSTORE_PACKAGE_NAME",
                                       description: "The package name of the application to use",
                                       default_value: CredentialsManager::AppfileConfig.try_fetch_value(:package_name),
                                       default_value_dynamic: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :apk,
                                       env_name: "AMAZON_APPSTORE_APK",
                                       description: "The path of the apk file",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :apk_paths,
                                       env_name: "AMAZON_APPSTORE_APK_PATHS",
                                       description: "An array of paths to APK files to upload",
                                       optional: true,
                                       type: Array),
          FastlaneCore::ConfigItem.new(key: :skip_upload_changelogs,
                                       env_name: "AMAZON_APPSTORE_SKIP_UPLOAD_CHANGELOGS",
                                       description: "Whether to skip uploading changelogs",
                                       default_value: false,
                                       optional: true,
                                       type: Boolean),
          FastlaneCore::ConfigItem.new(key: :metadata_path,
                                       env_name: "AMAZON_APPSTORE_METADATA_PATH",
                                       description: "Path to the directory containing the metadata files",
                                       default_value: "./fastlane/metadata/android",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :changes_not_sent_for_review,
                                       env_name: "AMAZON_APPSTORE_CHANGES_NOT_SENT_FOR_REVIEW",
                                       description: "Indicates that the changes in this edit will not be reviewed until they are explicitly sent for review from the Amazon Appstore Console UI",
                                       default_value: false,
                                       optional: true,
                                       type: Boolean),
          FastlaneCore::ConfigItem.new(key: :overwrite_upload,
                                       env_name: "AMAZON_APPSTORE_OVERWRITE_UPLOAD",
                                       description: "Whether to allow overwriting an existing upload",
                                       default_value: false,
                                       optional: true,
                                       type: Boolean),
          FastlaneCore::ConfigItem.new(key: :overwrite_upload_mode,
                                       env_name: "AMAZON_APPSTORE_OVERWRITE_UPLOAD_MODE",
                                       description: "Upload strategy. Can be 'new' or 'reuse'",
                                       default_value: 'new',
                                       verify_block: proc do |value|
                                         UI.user_error!("overwrite_upload can only be 'new' or 'reuse'") unless %w(new reuse).include?(value)
                                       end),
          FastlaneCore::ConfigItem.new(key: :timeout,
                                       env_name: "AMAZON_APPSTORE_TIMEOUT",
                                       description: "Timeout for read, open (in seconds)",
                                       default_value: 300,
                                       optional: true,
                                       type: Integer)
        ]
      end

      def self.is_supported?(platform)
        platform.equal?(:android)
      end
    end
  end
end
