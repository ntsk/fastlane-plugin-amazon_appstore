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
          UI.message("Deleting existing edits if needed (overwrite_upload: true)...")
          begin
            Helper::AmazonAppstoreHelper.delete_edits_if_exists(
              app_id: params[:package_name],
              token: token
            )
          rescue StandardError => e
            UI.error(e.message)
            UI.abort_with_message!("Failed to delete edits (overwrite_upload: true)")
          end
        end

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

        UI.message("Replacing apk...")
        begin
          version_code = Helper::AmazonAppstoreHelper.replace_apk(
            local_apk_path: params[:apk],
            app_id: params[:package_name],
            edit_id: edit_id,
            token: token
          )
        rescue StandardError => e
          UI.error(e.message)
          UI.abort_with_message!("Failed to replace apk")
        end
        UI.abort_with_message!("Failed to get version_code") if version_code.nil?

        UI.message("Updating release notes...")
        begin
          Helper::AmazonAppstoreHelper.update_listings(
            app_id: params[:package_name],
            edit_id: edit_id,
            token: token,
            version_code: version_code,
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
                                       optional: false,
                                       type: String),
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
