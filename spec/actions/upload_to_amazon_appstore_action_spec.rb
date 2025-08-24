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
      allow(Fastlane::Helper::AmazonAppstoreHelper).to receive(:replace_apks).and_return([{ version_code: 100, apk_id: 'apk_id_1' }])
      allow(Fastlane::Helper::AmazonAppstoreHelper).to receive(:update_listings_for_multiple_apks).and_return(nil)
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

    context 'failed to replace_apks' do
      it 'should raise error' do
        allow(Fastlane::Helper::AmazonAppstoreHelper).to receive(:replace_apks).and_raise('error')
        expect { Fastlane::Actions::UploadToAmazonAppstoreAction.run(params) }.to raise_error(FastlaneCore::Interface::FastlaneCommonException, 'Failed to replace APKs')
      end
    end

    context 'failed to update_listings_for_multiple_apks' do
      it 'should raise error' do
        allow(Fastlane::Helper::AmazonAppstoreHelper).to receive(:update_listings_for_multiple_apks).and_raise('error')
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
      let(:params) do
        {
          client_id: 'client_id',
          client_secret: 'client_secret',
          package_name: 'package_name',
          apk: 'apk',
          skip_upload_changelogs: false,
          metadata_path: './fastlane/metadata/android',
          changes_not_sent_for_review: true,
          overwrite_upload: false,
          timeout: 300
        }
      end
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

    context 'multiple APKs' do
      context 'with apk_paths parameter' do
        let(:params) do
          {
            client_id: 'client_id',
            client_secret: 'client_secret',
            package_name: 'package_name',
            apk_paths: ['path/to/apk1.apk', 'path/to/apk2.apk'],
            skip_upload_changelogs: false,
            metadata_path: './fastlane/metadata/android',
            changes_not_sent_for_review: false,
            overwrite_upload: false,
            timeout: 300
          }
        end

        before do
          allow(Fastlane::Helper::AmazonAppstoreHelper).to receive(:replace_apks).and_return([
                                                                                               { version_code: 100, apk_id: 'apk_id_1' },
                                                                                               { version_code: 200, apk_id: 'apk_id_2' }
                                                                                             ])
        end

        it 'should call replace_apks with correct parameters' do
          Fastlane::Actions::UploadToAmazonAppstoreAction.run(params)
          expect(Fastlane::Helper::AmazonAppstoreHelper).to have_received(:replace_apks).with(
            apk_paths: ['path/to/apk1.apk', 'path/to/apk2.apk'],
            app_id: 'package_name',
            edit_id: 'edit_id',
            token: 'token'
          )
        end

        it 'should call update_listings_for_multiple_apks with version codes' do
          Fastlane::Actions::UploadToAmazonAppstoreAction.run(params)
          expect(Fastlane::Helper::AmazonAppstoreHelper).to have_received(:update_listings_for_multiple_apks).with(
            app_id: 'package_name',
            edit_id: 'edit_id',
            token: 'token',
            version_codes: [100, 200],
            skip_upload_changelogs: false,
            metadata_path: './fastlane/metadata/android'
          )
        end

        it 'should call UI.success' do
          allow(Fastlane::UI).to receive(:success).and_return(true)
          Fastlane::Actions::UploadToAmazonAppstoreAction.run(params)
          expect(Fastlane::UI).to have_received(:success).once
        end
      end

      context 'with both apk and apk_paths parameters' do
        let(:params) do
          {
            client_id: 'client_id',
            client_secret: 'client_secret',
            package_name: 'package_name',
            apk: 'path/to/single.apk',
            apk_paths: ['path/to/apk1.apk', 'path/to/apk2.apk'],
            skip_upload_changelogs: false,
            metadata_path: './fastlane/metadata/android',
            changes_not_sent_for_review: false,
            overwrite_upload: false,
            timeout: 300
          }
        end

        before do
          allow(Fastlane::Helper::AmazonAppstoreHelper).to receive(:replace_apks).and_return([
                                                                                               { version_code: 50, apk_id: 'apk_id_single' },
                                                                                               { version_code: 100, apk_id: 'apk_id_1' },
                                                                                               { version_code: 200, apk_id: 'apk_id_2' }
                                                                                             ])
        end

        it 'should combine apk and apk_paths' do
          Fastlane::Actions::UploadToAmazonAppstoreAction.run(params)
          expect(Fastlane::Helper::AmazonAppstoreHelper).to have_received(:replace_apks).with(
            apk_paths: ['path/to/single.apk', 'path/to/apk1.apk', 'path/to/apk2.apk'],
            app_id: 'package_name',
            edit_id: 'edit_id',
            token: 'token'
          )
        end
      end

      context 'with no APK parameters' do
        let(:params) do
          {
            client_id: 'client_id',
            client_secret: 'client_secret',
            package_name: 'package_name',
            skip_upload_changelogs: false,
            metadata_path: './fastlane/metadata/android',
            changes_not_sent_for_review: false,
            overwrite_upload: false,
            timeout: 300
          }
        end

        it 'should raise error' do
          expect { Fastlane::Actions::UploadToAmazonAppstoreAction.run(params) }.to raise_error(FastlaneCore::Interface::FastlaneCommonException, "No APK files provided. Please provide either 'apk' or 'apk_paths' parameter")
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
      expect(Fastlane::Actions::UploadToAmazonAppstoreAction.available_options.size).to eq(10)
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
