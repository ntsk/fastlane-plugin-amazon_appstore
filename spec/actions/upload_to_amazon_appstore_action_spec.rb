describe Fastlane::Actions::UploadToAmazonAppstoreAction do
  describe '#run' do
    let(:params) do
      {
        client_id: 'client_id',
        client_secret: 'client_secret',
        package_name: 'package_name',
        apk: 'apk',
        skip_upload_changelogs: false,
        metadata_path: './fastlane/metadata/android',
        changes_not_sent_for_review: false,
        overwrite_upload: false,
        timeout: 300
      }
    end

    before do
      allow(Fastlane::Helper::AmazonAppstoreHelper).to receive(:setup).and_return(nil)
      allow(Fastlane::Helper::AmazonAppstoreHelper).to receive(:token).and_return('token')
      allow(Fastlane::Helper::AmazonAppstoreHelper).to receive(:delete_edits_if_exists).and_return(nil)
      allow(Fastlane::Helper::AmazonAppstoreHelper).to receive(:create_edits).and_return('edit_id')
      allow(Fastlane::Helper::AmazonAppstoreHelper).to receive(:replace_apk).and_return('version_code')
      allow(Fastlane::Helper::AmazonAppstoreHelper).to receive(:update_listings).and_return(nil)
      allow(Fastlane::Helper::AmazonAppstoreHelper).to receive(:commit_edits).and_return(nil)
    end

    context 'success' do
      it 'should call UI.success' do
        allow(Fastlane::UI).to receive(:success).and_return(true)
        Fastlane::Actions::UploadToAmazonAppstoreAction.run(params)
        expect(Fastlane::UI).to have_received(:success).once
      end
    end

    context 'failed to get token' do
      it 'should raise error' do
        allow(Fastlane::Helper::AmazonAppstoreHelper).to receive(:token).and_raise('error')
        expect { Fastlane::Actions::UploadToAmazonAppstoreAction.run(params) }.to raise_error(FastlaneCore::Interface::FastlaneCommonException, 'Failed to get token')
      end
    end

    context 'access token is nil' do
      it 'should raise error' do
        allow(Fastlane::Helper::AmazonAppstoreHelper).to receive(:token).and_return(nil)
        expect { Fastlane::Actions::UploadToAmazonAppstoreAction.run(params) }.to raise_error(FastlaneCore::Interface::FastlaneCommonException, 'Failed to get token')
      end
    end

    context 'failed to create edits' do
      it 'should raise error' do
        allow(Fastlane::Helper::AmazonAppstoreHelper).to receive(:create_edits).and_raise('error')
        expect { Fastlane::Actions::UploadToAmazonAppstoreAction.run(params) }.to raise_error(FastlaneCore::Interface::FastlaneCommonException, 'Failed to create edits')
      end
    end

    context 'edit_id is nil' do
      it 'should raise error' do
        allow(Fastlane::Helper::AmazonAppstoreHelper).to receive(:create_edits).and_return(nil)
        expect { Fastlane::Actions::UploadToAmazonAppstoreAction.run(params) }.to raise_error(FastlaneCore::Interface::FastlaneCommonException, 'Failed to get edit_id')
      end
    end

    context 'failed to replace_apk' do
      it 'should raise error' do
        allow(Fastlane::Helper::AmazonAppstoreHelper).to receive(:replace_apk).and_raise('error')
        expect { Fastlane::Actions::UploadToAmazonAppstoreAction.run(params) }.to raise_error(FastlaneCore::Interface::FastlaneCommonException, 'Failed to replace apk')
      end
    end

    context 'version_code is nil' do
      it 'should raise error' do
        allow(Fastlane::Helper::AmazonAppstoreHelper).to receive(:replace_apk).and_return(nil)
        expect { Fastlane::Actions::UploadToAmazonAppstoreAction.run(params) }.to raise_error(FastlaneCore::Interface::FastlaneCommonException, 'Failed to get version_code')
      end
    end

    context 'failed to update_listings' do
      it 'should raise error' do
        allow(Fastlane::Helper::AmazonAppstoreHelper).to receive(:update_listings).and_raise('error')
        expect { Fastlane::Actions::UploadToAmazonAppstoreAction.run(params) }.to raise_error(FastlaneCore::Interface::FastlaneCommonException, 'Failed to update listings')
      end
    end

    context 'failed to commit_edits' do
      it 'should raise error' do
        allow(Fastlane::Helper::AmazonAppstoreHelper).to receive(:commit_edits).and_raise('error')
        expect { Fastlane::Actions::UploadToAmazonAppstoreAction.run(params) }.to raise_error(FastlaneCore::Interface::FastlaneCommonException, 'Failed to commit edits')
      end
    end

    context 'when changes_not_sent_for_review is false' do
      it 'should call commit_edits' do
        Fastlane::Actions::UploadToAmazonAppstoreAction.run(params)
        expect(Fastlane::Helper::AmazonAppstoreHelper).to have_received(:commit_edits)
      end

      it 'should call UI.success' do
        allow(Fastlane::UI).to receive(:success).and_return(true)
        Fastlane::Actions::UploadToAmazonAppstoreAction.run(params)
        expect(Fastlane::UI).to have_received(:success).once
      end
    end

    context 'when changes_not_sent_for_review is true' do
      let(:params) { { changes_not_sent_for_review: true } }
      it 'should not call commit_edits' do
        Fastlane::Actions::UploadToAmazonAppstoreAction.run(params)
        expect(Fastlane::Helper::AmazonAppstoreHelper).not_to have_received(:commit_edits)
      end

      it 'should call UI.success' do
        allow(Fastlane::UI).to receive(:success).and_return(true)
        Fastlane::Actions::UploadToAmazonAppstoreAction.run(params)
        expect(Fastlane::UI).to have_received(:success).once
      end
    end

    context 'overwrite_upload' do
      context 'enabled' do
        let(:params) do
          {
            client_id: 'client_id',
            client_secret: 'client_secret',
            package_name: 'package_name',
            apk: 'apk',
            skip_upload_changelogs: false,
            metadata_path: './fastlane/metadata/android',
            changes_not_sent_for_review: false,
            overwrite_upload: true,
            timeout: 300
          }
        end

        it 'should call delete_edits_if_exists' do
          Fastlane::Actions::UploadToAmazonAppstoreAction.run(params)
          expect(Fastlane::Helper::AmazonAppstoreHelper).to have_received(:delete_edits_if_exists)
        end

        it 'should call UI.success' do
          allow(Fastlane::UI).to receive(:success).and_return(true)
          Fastlane::Actions::UploadToAmazonAppstoreAction.run(params)
          expect(Fastlane::UI).to have_received(:success).once
        end
      end

      context 'disabled' do
        let(:params) do
          {
            client_id: 'client_id',
            client_secret: 'client_secret',
            package_name: 'package_name',
            apk: 'apk',
            skip_upload_changelogs: false,
            metadata_path: './fastlane/metadata/android',
            changes_not_sent_for_review: false,
            overwrite_upload: false,
            timeout: 300
          }
        end

        it 'should not call delete_edits_if_exists' do
          Fastlane::Actions::UploadToAmazonAppstoreAction.run(params)
          expect(Fastlane::Helper::AmazonAppstoreHelper).not_to have_received(:delete_edits_if_exists)
        end

        it 'should call UI.success' do
          allow(Fastlane::UI).to receive(:success).and_return(true)
          Fastlane::Actions::UploadToAmazonAppstoreAction.run(params)
          expect(Fastlane::UI).to have_received(:success).once
        end
      end
    end
  end

  describe '#description' do
    it 'should return description' do
      expect(Fastlane::Actions::UploadToAmazonAppstoreAction.description).to eq("Upload apps to Amazon Appstore")
    end
  end

  describe '#authors' do
    it 'should return authors' do
      expect(Fastlane::Actions::UploadToAmazonAppstoreAction.authors).to eq(["ntsk"])
    end
  end

  describe '#return_value' do
    it 'should do nothing' do
      expect(Fastlane::Actions::UploadToAmazonAppstoreAction.return_value).to be nil
    end
  end

  describe '#details' do
    it 'should return details' do
      expect(Fastlane::Actions::UploadToAmazonAppstoreAction.details).to eq("Upload apps to Amazon Appstore")
    end
  end

  describe '#available_options' do
    it 'should return options' do
      expect(Fastlane::Actions::UploadToAmazonAppstoreAction.available_options.size).to eq(9)
    end
  end

  describe '#is_supported?' do
    context 'ios' do
      it 'should return false' do
        expect(Fastlane::Actions::UploadToAmazonAppstoreAction.is_supported?(:ios)).to be false
      end
    end

    context 'android' do
      it 'should return true' do
        expect(Fastlane::Actions::UploadToAmazonAppstoreAction.is_supported?(:android)).to be true
      end
    end
  end
end
