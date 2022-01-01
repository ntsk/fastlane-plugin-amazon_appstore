require 'fastlane/action'
require_relative '../helper/amazon_appstore_helper'

module Fastlane
  module Actions
    class UploadToAmazonAppstoreAction < Action
      def self.run(params)
        UI.message('------------------')
        UI.important("Fetching access token")
        token = Helper::AmazonAppstoreHelper.token(
          client_id: params[:client_id],
          client_secret: params[:client_secret]
        )
        UI.abort_with_message!("Failed to get token") if token.nil?

        UI.message('------------------')
        UI.important("Creating new edits")
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

        UI.message('------------------')
        UI.important("Replacing apk")
        begin
          Helper::AmazonAppstoreHelper.replace_apk(
            local_apk_path: params[:apk],
            app_id: params[:package_name],
            edit_id: edit_id,
            token: token
          )
        rescue StandardError => e
          UI.error(e.message)
          UI.abort_with_message!("Failed to replace apk")
        end

        UI.message('------------------')
        UI.important("Update listings")
        begin
          Helper::AmazonAppstoreHelper.update_listings(
            app_id: params[:package_name],
            edit_id: edit_id,
            token: token
          )
        rescue StandardError => e
          UI.error(e.message)
          UI.abort_with_message!("Failed to update listings")
        end

        UI.message('------------------')
        UI.important("Committing edits")
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

        UI.message('------------------')
        UI.success('Success')
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
                                      type: String)
        ]
      end

      def self.is_supported?(platform)
        platform.equal?(:android)
      end
    end
  end
end
