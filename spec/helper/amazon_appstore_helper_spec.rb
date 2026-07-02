require 'faraday'
require 'tmpdir'

describe Fastlane::Helper::AmazonAppstoreHelper do
  describe '#setup' do
    it 'should set timeout' do
      Fastlane::Helper::AmazonAppstoreHelper.setup(timeout: 100)
      expect(Fastlane::Helper::AmazonAppstoreHelper.send(:api_client).options.timeout).to eq(100)
      expect(Fastlane::Helper::AmazonAppstoreHelper.send(:api_client).options.open_timeout).to eq(100)
    end
  end

  describe '#token' do
    let(:auth_url) { Fastlane::Helper::AmazonAppstoreHelper::AUTH_URL }
    let(:client_id) { 'client_id' }
    let(:client_secret) { 'client_secret' }

    context 'success' do
      let(:response_body) do
        {
          access_token: 'access_token',
          scope: 'appstore::apps:readwrite',
          token_type: 'bearer',
          expires_in: 3600
        }
      end
      it 'should return access_token' do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_return(
          double(Faraday::Response, status: 201, body: response_body, success?: true)
        )
        expect(Fastlane::Helper::AmazonAppstoreHelper.token(client_id: client_id, client_secret: client_secret)).to eq('access_token')
      end
    end

    context 'failure' do
      let(:response_error_body) do
        {
          error_description: "Client authentication failed",
          error: "invalid_client"
        }
      end
      it 'should raise error' do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_return(
          double(Faraday::Response, status: 401, body: response_error_body, success?: false)
        )
        expect { Fastlane::Helper::AmazonAppstoreHelper.token(client_id: client_id, client_secret: client_secret) }.to raise_error(StandardError, response_error_body.to_s)
      end
    end
  end

  describe '#delete_edits_if_exists' do
    let(:app_id) { 'app_id' }
    let(:token) { 'token' }
    let(:url) { "api/appstore/v1/applications/#{app_id}/edits" }

    context 'success' do
      let(:response_body) do
        {
          id: 'id',
          status: 'IN_PROGRESS'
        }
      end

      let(:response_body_empty) do
        {}
      end

      let(:headers) do
        { 'Etag' => 'ABCD' }
      end

      it 'deletes the edit if it exists' do
        allow_any_instance_of(Faraday::Connection).to receive(:get).with(url).and_return(
          double(Faraday::Response, status: 200, body: response_body, success?: true, headers: headers)
        )
        allow_any_instance_of(Faraday::Connection).to receive(:delete).with("#{url}/id").and_return(
          double(Faraday::Response, status: 204, body: response_body_empty, success?: true)
        )
        expect(Fastlane::Helper::AmazonAppstoreHelper.delete_edits_if_exists(app_id: app_id, token: token)).to eq(nil)
      end

      it 'does nothing if the edit does not exist' do
        allow_any_instance_of(Faraday::Connection).to receive(:get).with(url).and_return(
          double(Faraday::Response, status: 200, body: response_body_empty, success?: true, headers: headers)
        )
        allow_any_instance_of(Faraday::Connection).to receive(:delete).with("#{url}/id").and_return(
          double(Faraday::Response, status: 204, body: response_body_empty, success?: true)
        )
        expect(Fastlane::Helper::AmazonAppstoreHelper.delete_edits_if_exists(app_id: app_id, token: token)).to eq(nil)
      end
    end

    context 'failure' do
      let(:response_error_body) do
        {
          error_description: "Client authentication failed",
          error: "invalid_client"
        }
      end

      let(:response_body) do
        {
          id: 'id',
          status: 'IN_PROGRESS'
        }
      end

      let(:headers) do
        { 'Etag' => 'ABCD' }
      end

      it 'raises an error if GET request failed' do
        allow_any_instance_of(Faraday::Connection).to receive(:get).and_return(
          double(Faraday::Response, status: 401, body: response_error_body, success?: false)
        )
        expect { Fastlane::Helper::AmazonAppstoreHelper.delete_edits_if_exists(app_id: app_id, token: token) }.to raise_error(StandardError, response_error_body.to_s)
      end

      it 'raises an error if DELETE request failed' do
        allow_any_instance_of(Faraday::Connection).to receive(:get).with(url).and_return(
          double(Faraday::Response, status: 200, body: response_body, success?: true, headers: headers)
        )
        allow_any_instance_of(Faraday::Connection).to receive(:delete).with("#{url}/id").and_return(
          double(Faraday::Response, status: 401, body: response_error_body, success?: false)
        )
        expect { Fastlane::Helper::AmazonAppstoreHelper.delete_edits_if_exists(app_id: app_id, token: token) }.to raise_error(StandardError, response_error_body.to_s)
      end
    end
  end

  describe '#create_edits' do
    let(:app_id) { 'app_id' }
    let(:token) { 'token' }
    let(:url) { "api/appstore/v1/applications/#{app_id}/edits" }

    context 'success' do
      let(:response_body) do
        {
          id: 'id',
          status: 'IN_PROGRESS'
        }
      end
      it 'should return edit_id' do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(url).and_return(
          double(Faraday::Response, status: 201, body: response_body, success?: true)
        )
        expect(Fastlane::Helper::AmazonAppstoreHelper.create_edits(app_id: app_id, token: token)).to eq('id')
      end
    end

    context 'failure' do
      let(:response_error_body) do
        {
          error_description: "Client authentication failed",
          error: "invalid_client"
        }
      end
      it 'should raise error' do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_return(
          double(Faraday::Response, status: 401, body: response_error_body, success?: false)
        )
        expect { Fastlane::Helper::AmazonAppstoreHelper.create_edits(app_id: app_id, token: token) }.to raise_error(StandardError, response_error_body.to_s)
      end
    end
  end

  describe '#replace_apks' do
    let(:apk_paths) { ['path/to/apk1.apk', 'path/to/apk2.apk'] }
    let(:app_id) { 'app_id' }
    let(:edit_id) { 'edit_id' }
    let(:token) { 'token' }
    let(:apk_id_1) { 'A' }
    let(:apk_id_2) { 'B' }
    let(:apks_url) { "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/apks" }
    let(:existing_apks) do
      [
        { versionCode: 1_000_000, id: apk_id_1, name: 'APK1' },
        { versionCode: 2_000_000, id: apk_id_2, name: 'APK2' }
      ]
    end

    before do
      allow_any_instance_of(Faraday::Connection).to receive(:get).with(apks_url).and_return(
        double(Faraday::Response, status: 200, body: existing_apks, success?: true)
      )
      allow_any_instance_of(Faraday::Connection).to receive(:get).with("api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/apks/#{apk_id_1}").and_return(
        double(Faraday::Response, status: 200, body: existing_apks[0], success?: true, headers: { 'Etag' => 'AAAA' })
      )
      allow_any_instance_of(Faraday::Connection).to receive(:get).with("api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/apks/#{apk_id_2}").and_return(
        double(Faraday::Response, status: 200, body: existing_apks[1], success?: true, headers: { 'Etag' => 'BBBB' })
      )
      allow_any_instance_of(Faraday::Connection).to receive(:put).and_return(
        double(Faraday::Response, status: 204, body: { versionCode: 3_000_000 }, success?: true)
      )
    end

    context 'replace existing APKs' do
      it 'should return version codes and apk ids' do
        result = Fastlane::Helper::AmazonAppstoreHelper.replace_apks(
          apk_paths: apk_paths,
          app_id: app_id,
          edit_id: edit_id,
          token: token
        )
        expect(result).to eq([
                               { version_code: 3_000_000, apk_id: apk_id_1 },
                               { version_code: 3_000_000, apk_id: apk_id_2 }
                             ])
      end
    end

    context 'upload new APKs when more paths than existing' do
      let(:apk_paths) { ['path/to/apk1.apk', 'path/to/apk2.apk', 'path/to/apk3.apk'] }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with("#{apks_url}/upload").and_return(
          double(Faraday::Response, status: 201, body: { versionCode: 4_000_000, id: 'C' }, success?: true)
        )
      end

      it 'should replace existing and upload new APKs' do
        result = Fastlane::Helper::AmazonAppstoreHelper.replace_apks(
          apk_paths: apk_paths,
          app_id: app_id,
          edit_id: edit_id,
          token: token
        )
        expect(result).to eq([
                               { version_code: 3_000_000, apk_id: apk_id_1 },
                               { version_code: 3_000_000, apk_id: apk_id_2 },
                               { version_code: 4_000_000, apk_id: 'C' }
                             ])
      end
    end

    context 'delete excess APKs when fewer paths than existing' do
      let(:apk_paths) { ['path/to/apk1.apk'] }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:delete).with("api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/apks/#{apk_id_2}").and_return(
          double(Faraday::Response, status: 204, body: {}, success?: true)
        )
      end

      it 'should replace first APK and delete remaining' do
        result = Fastlane::Helper::AmazonAppstoreHelper.replace_apks(
          apk_paths: apk_paths,
          app_id: app_id,
          edit_id: edit_id,
          token: token
        )
        expect(result).to eq([
                               { version_code: 3_000_000, apk_id: apk_id_1 }
                             ])
      end
    end
  end

  describe '#upload_apk' do
    let(:local_apk_path) { 'path/to/new.apk' }
    let(:app_id) { 'app_id' }
    let(:edit_id) { 'edit_id' }
    let(:token) { 'token' }
    let(:upload_url) { "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/apks/upload" }
    let(:upload_response) do
      { versionCode: 5_000_000, id: 'NEW_APK_ID' }
    end

    before do
      allow_any_instance_of(Faraday::Connection).to receive(:post).with(upload_url).and_return(
        double(Faraday::Response, status: 201, body: upload_response, success?: true)
      )
    end

    context 'success' do
      it 'should return version code and apk id' do
        result = Fastlane::Helper::AmazonAppstoreHelper.upload_apk(
          local_apk_path: local_apk_path,
          app_id: app_id,
          edit_id: edit_id,
          token: token
        )
        expect(result).to eq({ version_code: 5_000_000, apk_id: 'NEW_APK_ID' })
      end
    end
  end

  describe '#delete_apk' do
    let(:app_id) { 'app_id' }
    let(:edit_id) { 'edit_id' }
    let(:apk_id) { 'DELETE_APK_ID' }
    let(:token) { 'token' }
    let(:apk_url) { "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/apks/#{apk_id}" }

    before do
      allow_any_instance_of(Faraday::Connection).to receive(:get).with(apk_url).and_return(
        double(Faraday::Response, status: 200, body: { id: apk_id }, success?: true, headers: { 'Etag' => 'DELETE_ETAG' })
      )
      allow_any_instance_of(Faraday::Connection).to receive(:delete).with(apk_url).and_return(
        double(Faraday::Response, status: 204, body: {}, success?: true)
      )
    end

    context 'success' do
      it 'should delete APK successfully' do
        expect do
          Fastlane::Helper::AmazonAppstoreHelper.delete_apk(
            app_id: app_id,
            edit_id: edit_id,
            apk_id: apk_id,
            token: token
          )
        end.not_to raise_error
      end
    end
  end

  describe '#update_changelogs' do
    let(:app_id) { 'app_id' }
    let(:edit_id) { 'edit_id' }
    let(:token) { 'token' }
    let(:version_codes) { [100, 200, 300] }
    let(:skip_upload_changelogs) { false }
    let(:metadata_path) { './fastlane/metadata/android' }
    let(:listings_url) { "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/listings" }
    let(:listings_response_body) do
      {
        listings: {
          'en-US': {
            language: 'en-US',
            title: 'title',
            recentChanges: nil
          },
          'ja-JP': {
            language: 'ja-JP',
            title: 'title',
            recentChanges: nil
          }
        }
      }
    end

    before do
      allow_any_instance_of(Faraday::Connection).to receive(:get).with(listings_url).and_return(
        double(Faraday::Response, status: 200, body: listings_response_body, success?: true, headers: { 'Etag' => 'MULTI_ETAG' })
      )
      allow_any_instance_of(Faraday::Connection).to receive(:put).and_return(
        double(Faraday::Response, status: 204, body: {}, success?: true)
      )
      allow(Fastlane::Helper::AmazonAppstoreHelper).to receive(:find_changelog).and_return('Test changelog')
    end

    context 'success' do
      it 'should update listings for all languages' do
        expect do
          Fastlane::Helper::AmazonAppstoreHelper.update_changelogs(
            app_id: app_id,
            edit_id: edit_id,
            token: token,
            version_codes: version_codes,
            skip_upload_changelogs: skip_upload_changelogs,
            metadata_path: metadata_path
          )
        end.not_to raise_error
      end

      it 'should call find_changelog with the highest version code for each language' do
        Fastlane::Helper::AmazonAppstoreHelper.update_changelogs(
          app_id: app_id,
          edit_id: edit_id,
          token: token,
          version_codes: version_codes,
          skip_upload_changelogs: skip_upload_changelogs,
          metadata_path: metadata_path
        )
        expect(Fastlane::Helper::AmazonAppstoreHelper).to have_received(:find_changelog).with(
          language: 'en-US',
          version_code: 300,
          skip_upload_changelogs: false,
          metadata_path: metadata_path
        )
        expect(Fastlane::Helper::AmazonAppstoreHelper).to have_received(:find_changelog).with(
          language: 'ja-JP',
          version_code: 300,
          skip_upload_changelogs: false,
          metadata_path: metadata_path
        )
      end
    end

    context 'version_codes is empty' do
      let(:version_codes) { [] }

      it 'should fall back to the placeholder without reading changelog files' do
        Fastlane::Helper::AmazonAppstoreHelper.update_changelogs(
          app_id: app_id,
          edit_id: edit_id,
          token: token,
          version_codes: version_codes,
          skip_upload_changelogs: skip_upload_changelogs,
          metadata_path: metadata_path
        )
        expect(Fastlane::Helper::AmazonAppstoreHelper).to have_received(:find_changelog).with(
          language: 'en-US',
          version_code: nil,
          skip_upload_changelogs: false,
          metadata_path: metadata_path
        )
        expect(Fastlane::Helper::AmazonAppstoreHelper).to have_received(:find_changelog).with(
          language: 'ja-JP',
          version_code: nil,
          skip_upload_changelogs: false,
          metadata_path: metadata_path
        )
      end

      it 'should send the listing update so the placeholder is committed' do
        expect_any_instance_of(Faraday::Connection).to receive(:put).twice.and_return(
          double(Faraday::Response, status: 204, body: {}, success?: true)
        )
        Fastlane::Helper::AmazonAppstoreHelper.update_changelogs(
          app_id: app_id,
          edit_id: edit_id,
          token: token,
          version_codes: version_codes,
          skip_upload_changelogs: skip_upload_changelogs,
          metadata_path: metadata_path
        )
      end

      context 'and release notes already exist' do
        let(:listings_response_body) do
          {
            listings: {
              'en-US': {
                language: 'en-US',
                title: 'title',
                recentChanges: 'Existing release notes'
              },
              'ja-JP': {
                language: 'ja-JP',
                title: 'title',
                recentChanges: '既存のリリースノート'
              }
            }
          }
        end

        it 'should not overwrite existing release notes' do
          expect_any_instance_of(Faraday::Connection).not_to receive(:put)
          Fastlane::Helper::AmazonAppstoreHelper.update_changelogs(
            app_id: app_id,
            edit_id: edit_id,
            token: token,
            version_codes: version_codes,
            skip_upload_changelogs: skip_upload_changelogs,
            metadata_path: metadata_path
          )
        end
      end
    end

    context 'skip_upload_changelogs is true' do
      let(:skip_upload_changelogs) { true }

      it 'should still write the placeholder changelog for each language' do
        Fastlane::Helper::AmazonAppstoreHelper.update_changelogs(
          app_id: app_id,
          edit_id: edit_id,
          token: token,
          version_codes: version_codes,
          skip_upload_changelogs: skip_upload_changelogs,
          metadata_path: metadata_path
        )
        expect(Fastlane::Helper::AmazonAppstoreHelper).to have_received(:find_changelog).with(
          language: 'en-US',
          version_code: 300,
          skip_upload_changelogs: true,
          metadata_path: metadata_path
        )
        expect(Fastlane::Helper::AmazonAppstoreHelper).to have_received(:find_changelog).with(
          language: 'ja-JP',
          version_code: 300,
          skip_upload_changelogs: true,
          metadata_path: metadata_path
        )
      end

      it 'should send the listing update so the placeholder is committed' do
        expect_any_instance_of(Faraday::Connection).to receive(:put).twice.and_return(
          double(Faraday::Response, status: 204, body: {}, success?: true)
        )
        Fastlane::Helper::AmazonAppstoreHelper.update_changelogs(
          app_id: app_id,
          edit_id: edit_id,
          token: token,
          version_codes: version_codes,
          skip_upload_changelogs: skip_upload_changelogs,
          metadata_path: metadata_path
        )
      end

      it 'should write "-" as the recentChanges value' do
        allow(Fastlane::Helper::AmazonAppstoreHelper).to receive(:find_changelog).and_call_original
        captured_bodies = []
        request_spy = double('request', headers: {})
        allow(request_spy).to receive(:body=) { |value| captured_bodies << value }
        allow_any_instance_of(Faraday::Connection).to receive(:put) do |_instance, _path, &block|
          block.call(request_spy)
          double(Faraday::Response, status: 204, body: {}, success?: true)
        end

        Fastlane::Helper::AmazonAppstoreHelper.update_changelogs(
          app_id: app_id,
          edit_id: edit_id,
          token: token,
          version_codes: version_codes,
          skip_upload_changelogs: skip_upload_changelogs,
          metadata_path: metadata_path
        )

        parsed = captured_bodies.map { |body| JSON.parse(body) }
        expect(parsed.length).to eq(2)
        expect(parsed).to all(include('recentChanges' => '-'))
      end
    end

    context 'skip_upload_changelogs is true and release notes exist for only some languages' do
      let(:skip_upload_changelogs) { true }
      let(:listings_response_body) do
        {
          listings: {
            'en-US': {
              language: 'en-US',
              title: 'title',
              recentChanges: nil
            },
            'ja-JP': {
              language: 'ja-JP',
              title: 'title',
              recentChanges: '既存のリリースノート'
            }
          }
        }
      end

      it 'should fill the placeholder only for languages without release notes' do
        expect_any_instance_of(Faraday::Connection).to receive(:put).once.with(
          "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/listings/en-US"
        ).and_return(
          double(Faraday::Response, status: 204, body: {}, success?: true)
        )
        Fastlane::Helper::AmazonAppstoreHelper.update_changelogs(
          app_id: app_id,
          edit_id: edit_id,
          token: token,
          version_codes: version_codes,
          skip_upload_changelogs: skip_upload_changelogs,
          metadata_path: metadata_path
        )
      end
    end

    context 'skip_upload_changelogs is true and release notes already exist' do
      let(:skip_upload_changelogs) { true }
      let(:listings_response_body) do
        {
          listings: {
            'en-US': {
              language: 'en-US',
              title: 'title',
              recentChanges: 'Existing release notes'
            },
            'ja-JP': {
              language: 'ja-JP',
              title: 'title',
              recentChanges: '既存のリリースノート'
            }
          }
        }
      end

      it 'should not overwrite existing release notes' do
        expect_any_instance_of(Faraday::Connection).not_to receive(:put)
        Fastlane::Helper::AmazonAppstoreHelper.update_changelogs(
          app_id: app_id,
          edit_id: edit_id,
          token: token,
          version_codes: version_codes,
          skip_upload_changelogs: skip_upload_changelogs,
          metadata_path: metadata_path
        )
      end
    end
  end

  describe '#find_changelog' do
    let(:language) { 'en-US' }
    let(:version_code) { 100 }

    it 'should return "-" when skip_upload_changelogs is true even if a changelog file exists' do
      Dir.mktmpdir do |metadata_path|
        changelogs_dir = File.join(metadata_path, language, 'changelogs')
        FileUtils.mkdir_p(changelogs_dir)
        File.write(File.join(changelogs_dir, "#{version_code}.txt"), 'Version changelog')

        result = Fastlane::Helper::AmazonAppstoreHelper.send(
          :find_changelog,
          language: language,
          version_code: version_code,
          skip_upload_changelogs: true,
          metadata_path: metadata_path
        )
        expect(result).to eq('-')
      end
    end

    it 'should return "-" when version_code is nil' do
      Dir.mktmpdir do |metadata_path|
        changelogs_dir = File.join(metadata_path, language, 'changelogs')
        FileUtils.mkdir_p(changelogs_dir)
        File.write(File.join(changelogs_dir, 'default.txt'), 'Default changelog')

        result = Fastlane::Helper::AmazonAppstoreHelper.send(
          :find_changelog,
          language: language,
          version_code: nil,
          skip_upload_changelogs: false,
          metadata_path: metadata_path
        )
        expect(result).to eq('-')
      end
    end

    it 'should return "-" when no changelog file exists' do
      Dir.mktmpdir do |metadata_path|
        result = Fastlane::Helper::AmazonAppstoreHelper.send(
          :find_changelog,
          language: language,
          version_code: version_code,
          skip_upload_changelogs: false,
          metadata_path: metadata_path
        )
        expect(result).to eq('-')
      end
    end

    it 'should return the changelog file content for the version code' do
      Dir.mktmpdir do |metadata_path|
        changelogs_dir = File.join(metadata_path, language, 'changelogs')
        FileUtils.mkdir_p(changelogs_dir)
        File.write(File.join(changelogs_dir, "#{version_code}.txt"), 'Version changelog')

        result = Fastlane::Helper::AmazonAppstoreHelper.send(
          :find_changelog,
          language: language,
          version_code: version_code,
          skip_upload_changelogs: false,
          metadata_path: metadata_path
        )
        expect(result).to eq('Version changelog')
      end
    end

    it 'should fall back to default.txt when the version file is missing' do
      Dir.mktmpdir do |metadata_path|
        changelogs_dir = File.join(metadata_path, language, 'changelogs')
        FileUtils.mkdir_p(changelogs_dir)
        File.write(File.join(changelogs_dir, 'default.txt'), 'Default changelog')

        result = Fastlane::Helper::AmazonAppstoreHelper.send(
          :find_changelog,
          language: language,
          version_code: version_code,
          skip_upload_changelogs: false,
          metadata_path: metadata_path
        )
        expect(result).to eq('Default changelog')
      end
    end
  end

  describe '#upload_image' do
    let(:app_id) { 'app_id' }
    let(:edit_id) { 'edit_id' }
    let(:language) { 'en-US' }
    let(:image_type) { 'screenshots' }
    let(:image_path) { 'path/to/screenshot.png' }
    let(:token) { 'token' }
    let(:images_url) { "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/listings/#{language}/#{image_type}" }
    let(:upload_url) { "#{images_url}/upload" }

    before do
      allow_any_instance_of(Faraday::Connection).to receive(:get).with(images_url).and_return(
        double(Faraday::Response, status: 200, body: [], success?: true, headers: { 'Etag' => 'IMG_ETAG' })
      )
    end

    context 'success' do
      let(:response_body) { { id: 'img_123' } }

      it 'should return image id' do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(upload_url).and_return(
          double(Faraday::Response, status: 200, body: response_body, success?: true)
        )
        result = Fastlane::Helper::AmazonAppstoreHelper.upload_image(
          app_id: app_id,
          edit_id: edit_id,
          language: language,
          image_type: image_type,
          image_path: image_path,
          token: token
        )
        expect(result).to eq('img_123')
      end
    end

    context 'failure' do
      let(:response_error_body) { { message: 'Upload failed' } }

      it 'should raise error' do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(upload_url).and_return(
          double(Faraday::Response, status: 400, body: response_error_body, success?: false)
        )
        expect do
          Fastlane::Helper::AmazonAppstoreHelper.upload_image(
            app_id: app_id,
            edit_id: edit_id,
            language: language,
            image_type: image_type,
            image_path: image_path,
            token: token
          )
        end.to raise_error(StandardError, response_error_body.to_s)
      end
    end
  end

  describe '#get_images' do
    let(:app_id) { 'app_id' }
    let(:edit_id) { 'edit_id' }
    let(:language) { 'en-US' }
    let(:image_type) { 'screenshots' }
    let(:token) { 'token' }
    let(:images_url) { "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/listings/#{language}/#{image_type}" }

    context 'success' do
      let(:response_body) { [{ id: 'img_1' }, { id: 'img_2' }] }

      it 'should return images list' do
        allow_any_instance_of(Faraday::Connection).to receive(:get).with(images_url).and_return(
          double(Faraday::Response, status: 200, body: response_body, success?: true)
        )
        result = Fastlane::Helper::AmazonAppstoreHelper.get_images(
          app_id: app_id,
          edit_id: edit_id,
          language: language,
          image_type: image_type,
          token: token
        )
        expect(result).to eq([{ id: 'img_1' }, { id: 'img_2' }])
      end
    end

    context 'failure' do
      let(:response_error_body) { { message: 'Failed to get images' } }

      it 'should raise error' do
        allow_any_instance_of(Faraday::Connection).to receive(:get).with(images_url).and_return(
          double(Faraday::Response, status: 400, body: response_error_body, success?: false)
        )
        expect do
          Fastlane::Helper::AmazonAppstoreHelper.get_images(
            app_id: app_id,
            edit_id: edit_id,
            language: language,
            image_type: image_type,
            token: token
          )
        end.to raise_error(StandardError, response_error_body.to_s)
      end
    end
  end

  describe '#delete_all_images' do
    let(:app_id) { 'app_id' }
    let(:edit_id) { 'edit_id' }
    let(:language) { 'en-US' }
    let(:image_type) { 'screenshots' }
    let(:token) { 'token' }
    let(:images_url) { "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/listings/#{language}/#{image_type}" }

    context 'success' do
      it 'should delete all images' do
        allow_any_instance_of(Faraday::Connection).to receive(:get).with(images_url).and_return(
          double(Faraday::Response, status: 200, body: [], success?: true, headers: { 'Etag' => 'ETAG123' })
        )
        allow_any_instance_of(Faraday::Connection).to receive(:delete).with(images_url).and_return(
          double(Faraday::Response, status: 204, body: {}, success?: true)
        )
        expect do
          Fastlane::Helper::AmazonAppstoreHelper.delete_all_images(
            app_id: app_id,
            edit_id: edit_id,
            language: language,
            image_type: image_type,
            token: token
          )
        end.not_to raise_error
      end
    end

    context 'failure' do
      let(:response_error_body) { { message: 'Delete failed' } }

      it 'should raise error' do
        allow_any_instance_of(Faraday::Connection).to receive(:get).with(images_url).and_return(
          double(Faraday::Response, status: 200, body: [], success?: true, headers: { 'Etag' => 'ETAG123' })
        )
        allow_any_instance_of(Faraday::Connection).to receive(:delete).with(images_url).and_return(
          double(Faraday::Response, status: 400, body: response_error_body, success?: false)
        )
        expect do
          Fastlane::Helper::AmazonAppstoreHelper.delete_all_images(
            app_id: app_id,
            edit_id: edit_id,
            language: language,
            image_type: image_type,
            token: token
          )
        end.to raise_error(StandardError, response_error_body.to_s)
      end
    end
  end

  describe '#upload_video' do
    let(:app_id) { 'app_id' }
    let(:edit_id) { 'edit_id' }
    let(:language) { 'en-US' }
    let(:video_path) { 'path/to/video.mp4' }
    let(:token) { 'token' }
    let(:videos_url) { "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/listings/#{language}/videos" }

    before do
      allow_any_instance_of(Faraday::Connection).to receive(:get).with(videos_url).and_return(
        double(Faraday::Response, status: 200, body: [], success?: true, headers: { 'Etag' => 'VID_ETAG' })
      )
    end

    context 'success' do
      let(:response_body) { { id: 'video_123' } }

      it 'should return video id' do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(videos_url).and_return(
          double(Faraday::Response, status: 201, body: response_body, success?: true)
        )
        result = Fastlane::Helper::AmazonAppstoreHelper.upload_video(
          app_id: app_id,
          edit_id: edit_id,
          language: language,
          video_path: video_path,
          token: token
        )
        expect(result).to eq('video_123')
      end
    end

    context 'failure' do
      let(:response_error_body) { { message: 'Upload failed' } }

      it 'should raise error' do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(videos_url).and_return(
          double(Faraday::Response, status: 400, body: response_error_body, success?: false)
        )
        expect do
          Fastlane::Helper::AmazonAppstoreHelper.upload_video(
            app_id: app_id,
            edit_id: edit_id,
            language: language,
            video_path: video_path,
            token: token
          )
        end.to raise_error(StandardError, response_error_body.to_s)
      end
    end
  end

  describe '#update_listing_metadata' do
    let(:app_id) { 'app_id' }
    let(:edit_id) { 'edit_id' }
    let(:language) { 'en-US' }
    let(:token) { 'token' }
    let(:listings_url) { "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/listings/#{language}" }
    let(:existing_data) do
      {
        language: 'en-US',
        title: 'Old Title',
        fullDescription: 'Old full description',
        shortDescription: 'Old short description',
        recentChanges: 'Some changes',
        featureBullets: ['bullet1'],
        keywords: ['keyword1']
      }
    end
    let(:listing_data) do
      {
        title: 'My App',
        fullDescription: 'Full description',
        shortDescription: 'Short description'
      }
    end

    before do
      allow_any_instance_of(Faraday::Connection).to receive(:get).with(listings_url).and_return(
        double(Faraday::Response, status: 200, body: existing_data, success?: true, headers: { 'Etag' => 'ETAG123' })
      )
    end

    context 'success' do
      it 'should update listing metadata' do
        allow_any_instance_of(Faraday::Connection).to receive(:put).with(listings_url).and_return(
          double(Faraday::Response, status: 200, body: existing_data.merge(listing_data), success?: true)
        )
        expect do
          Fastlane::Helper::AmazonAppstoreHelper.update_listing_metadata(
            app_id: app_id,
            edit_id: edit_id,
            language: language,
            listing_data: listing_data,
            token: token
          )
        end.not_to raise_error
      end

      it 'should merge with existing data preserving unmodified fields' do
        put_body = nil
        allow_any_instance_of(Faraday::Connection).to receive(:put).with(listings_url) do |_, &block|
          request = double('request', headers: {})
          allow(request).to receive(:body=) { |v| put_body = v }
          allow(request).to receive(:headers).and_return({})
          block.call(request)
          double(Faraday::Response, status: 200, body: {}, success?: true)
        end

        Fastlane::Helper::AmazonAppstoreHelper.update_listing_metadata(
          app_id: app_id,
          edit_id: edit_id,
          language: language,
          listing_data: listing_data,
          token: token
        )

        parsed = JSON.parse(put_body, symbolize_names: true)
        expect(parsed[:title]).to eq('My App')
        expect(parsed[:featureBullets]).to eq(['bullet1'])
        expect(parsed[:keywords]).to eq(['keyword1'])
        expect(parsed[:recentChanges]).to eq('Some changes')
      end
    end

    context 'failure' do
      let(:response_error_body) { { message: 'Update failed' } }

      it 'should raise error' do
        allow_any_instance_of(Faraday::Connection).to receive(:put).with(listings_url).and_return(
          double(Faraday::Response, status: 400, body: response_error_body, success?: false)
        )
        expect do
          Fastlane::Helper::AmazonAppstoreHelper.update_listing_metadata(
            app_id: app_id,
            edit_id: edit_id,
            language: language,
            listing_data: listing_data,
            token: token
          )
        end.to raise_error(StandardError, response_error_body.to_s)
      end
    end
  end

  describe '#load_metadata_from_files' do
    let(:metadata_path) { './spec/fixtures/metadata/android' }
    let(:language) { 'en-US' }

    before do
      FileUtils.mkdir_p(File.join(metadata_path, language))
      File.write(File.join(metadata_path, language, 'title.txt'), 'Test App')
      File.write(File.join(metadata_path, language, 'short_description.txt'), 'Short desc')
      File.write(File.join(metadata_path, language, 'full_description.txt'), 'Full description')
    end

    after do
      FileUtils.rm_rf('./spec/fixtures')
    end

    context 'all files exist' do
      it 'should return metadata hash' do
        result = Fastlane::Helper::AmazonAppstoreHelper.load_metadata_from_files(
          metadata_path: metadata_path,
          language: language
        )
        expect(result[:title]).to eq('Test App')
        expect(result[:shortDescription]).to eq('Short desc')
        expect(result[:fullDescription]).to eq('Full description')
      end
    end

    context 'some files missing' do
      before do
        FileUtils.rm(File.join(metadata_path, language, 'short_description.txt'))
      end

      it 'should return nil for missing fields' do
        result = Fastlane::Helper::AmazonAppstoreHelper.load_metadata_from_files(
          metadata_path: metadata_path,
          language: language
        )
        expect(result[:title]).to eq('Test App')
        expect(result[:shortDescription]).to be_nil
        expect(result[:fullDescription]).to eq('Full description')
      end
    end
  end

  describe '#find_images_for_type' do
    let(:metadata_path) { './spec/fixtures/metadata/android' }
    let(:language) { 'en-US' }
    let(:images_path) { File.join(metadata_path, language, 'images') }

    before do
      FileUtils.mkdir_p(File.join(images_path, 'phoneScreenshots'))
    end

    after do
      FileUtils.rm_rf('./spec/fixtures')
    end

    context 'screenshots' do
      before do
        FileUtils.touch(File.join(images_path, 'phoneScreenshots', '1.png'))
        FileUtils.touch(File.join(images_path, 'phoneScreenshots', '2.png'))
      end

      it 'should return screenshot files sorted' do
        result = Fastlane::Helper::AmazonAppstoreHelper.find_images_for_type(
          metadata_path: metadata_path,
          language: language,
          image_type: 'screenshots'
        )
        expect(result.length).to eq(2)
        expect(result[0]).to end_with('1.png')
        expect(result[1]).to end_with('2.png')
      end
    end

    context 'icon' do
      before do
        FileUtils.touch(File.join(images_path, 'icon.png'))
      end

      it 'should return icon file' do
        result = Fastlane::Helper::AmazonAppstoreHelper.find_images_for_type(
          metadata_path: metadata_path,
          language: language,
          image_type: 'small-icons'
        )
        expect(result.length).to eq(1)
        expect(result[0]).to end_with('icon.png')
      end
    end

    context 'no images found' do
      it 'should return empty array' do
        result = Fastlane::Helper::AmazonAppstoreHelper.find_images_for_type(
          metadata_path: metadata_path,
          language: language,
          image_type: 'promo-images'
        )
        expect(result).to eq([])
      end
    end
  end

  describe '#commit_edits' do
    let(:app_id) { 'app_id' }
    let(:edit_id) { 'edit_id' }
    let(:token) { 'token' }
    let(:edits_url) { "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}" }
    let(:commit_url) { "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/commit" }
    let(:response_body) do
      {
        id: 'id',
        status: 'IN_PROGRESS'
      }
    end
    let(:response_error_body) do
      {
        error_description: "Client authentication failed",
        error: "invalid_client"
      }
    end

    before do
      allow_any_instance_of(Faraday::Connection).to receive(:get).with(edits_url).and_return(
        double(Faraday::Response, status: 200, body: response_body, success?: true, headers: { 'Etag' => 'AAAA' })
      )
      allow_any_instance_of(Faraday::Connection).to receive(:post).with(commit_url).and_return(
        double(Faraday::Response, status: 201, body: response_body, success?: true)
      )
    end

    context 'success' do
      it 'should not raise error' do
        expect(Fastlane::Helper::AmazonAppstoreHelper.commit_edits(app_id: app_id, edit_id: edit_id, token: token)).to eq(nil)
      end
    end

    context 'failed to get edits' do
      it 'should raise error' do
        allow_any_instance_of(Faraday::Connection).to receive(:get).with(edits_url).and_return(
          double(Faraday::Response, status: 401, body: response_error_body, success?: false)
        )
        expect { Fastlane::Helper::AmazonAppstoreHelper.commit_edits(app_id: app_id, edit_id: edit_id, token: token) }.to raise_error(StandardError, response_error_body.to_s)
      end
    end

    context 'failed to commit edits' do
      it 'should raise error' do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(commit_url).and_return(
          double(Faraday::Response, status: 401, body: response_error_body, success?: false)
        )
        expect { Fastlane::Helper::AmazonAppstoreHelper.commit_edits(app_id: app_id, edit_id: edit_id, token: token) }.to raise_error(StandardError, response_error_body.to_s)
      end
    end
  end
end
