require 'fastlane_core/ui/ui'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")

  module Helper
    class AmazonAppstoreHelper
      # class methods that you define here become available in your action
      # as `Helper::AmazonAppstoreHelper.your_method`
      #
      def self.show_message
        UI.message("Hello from the amazon_appstore plugin helper!")
      end
    end
  end
end
