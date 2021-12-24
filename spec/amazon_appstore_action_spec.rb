describe Fastlane::Actions::AmazonAppstoreAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The amazon_appstore plugin is working!")

      Fastlane::Actions::AmazonAppstoreAction.run(nil)
    end
  end
end
