require 'faraday'

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

  describe '#replace_apk' do
    let(:local_apk_path) { 'local_apk_path' }
    let(:app_id) { 'app_id' }
    let(:edit_id) { 'edit_id' }
    let(:token) { 'token' }
    let(:apk_id_1) { 'A' }
    let(:apk_id_2) { 'B' }
    let(:apks_url) { "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/apks" }
    let(:apk_url) { "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/apks/#{apk_id_1}" }
    let(:replace_url) { "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/apks/#{apk_id_1}/replace" }
    let(:apks_response_body) do
      [
        {
          versionCode: '1000000',
          id: apk_id_1,
          name: 'APK1'
        },
        {
          versionCode: '2000000',
          id: apk_id_2,
          name: 'APK2'
        }
      ]
    end
    let(:apk_response_body) do
      {
        versionCode: '1000000',
        id: apk_id_1,
        name: 'APK1'
      }
    end
    let(:response_error_body) do
      {
        error_description: "Client authentication failed",
        error: "invalid_client"
      }
    end

    before do
      allow_any_instance_of(Faraday::Connection).to receive(:get).with(apks_url).and_return(
        double(Faraday::Response, status: 200, body: apks_response_body, success?: true)
      )
      allow_any_instance_of(Faraday::Connection).to receive(:get).with(apk_url).and_return(
        double(Faraday::Response, status: 200, body: apk_response_body, success?: true, headers: { 'Etag' => 'AAAA' })
      )
      allow_any_instance_of(Faraday::Connection).to receive(:put).with(replace_url).and_return(
        double(Faraday::Response, status: 204, body: apk_response_body, success?: true)
      )
    end

    context 'success' do
      it 'should return version_code' do
        expect(Fastlane::Helper::AmazonAppstoreHelper.replace_apk(local_apk_path: local_apk_path, app_id: app_id, edit_id: edit_id, token: token)).to eq('1000000')
      end
    end

    context 'failed to get apks' do
      it 'should raise error' do
        allow_any_instance_of(Faraday::Connection).to receive(:get).with(apks_url).and_return(
          double(Faraday::Response, status: 401, body: response_error_body, success?: false)
        )
        expect { Fastlane::Helper::AmazonAppstoreHelper.replace_apk(local_apk_path: local_apk_path, app_id: app_id, edit_id: edit_id, token: token) }.to raise_error(StandardError, response_error_body.to_s)
      end
    end

    context 'failed to get apk_id' do
      let(:apks_response_body) do
        [
          {
            versionCode: '1000000',
            name: 'APK1'
          },
          {
            versionCode: '2000000',
            name: 'APK2'
          }
        ]
      end
      it 'should raise error' do
        allow_any_instance_of(Faraday::Connection).to receive(:get).with(apks_url).and_return(
          double(Faraday::Response, status: 200, body: apks_response_body, success?: true)
        )
        expect { Fastlane::Helper::AmazonAppstoreHelper.replace_apk(local_apk_path: local_apk_path, app_id: app_id, edit_id: edit_id, token: token) }.to raise_error(StandardError, 'apk_id is nil')
      end
    end

    context 'failed to get target apk Etag' do
      it 'should raise error' do
        allow_any_instance_of(Faraday::Connection).to receive(:get).with(apk_url).and_return(
          double(Faraday::Response, status: 401, body: response_error_body, success?: false)
        )
        expect { Fastlane::Helper::AmazonAppstoreHelper.replace_apk(local_apk_path: local_apk_path, app_id: app_id, edit_id: edit_id, token: token) }.to raise_error(StandardError, response_error_body.to_s)
      end
    end

    context 'failed to replace apk' do
      it 'should raise error' do
        allow_any_instance_of(Faraday::Connection).to receive(:put).with(replace_url).and_return(
          double(Faraday::Response, status: 401, body: response_error_body, success?: false)
        )
        expect { Fastlane::Helper::AmazonAppstoreHelper.replace_apk(local_apk_path: local_apk_path, app_id: app_id, edit_id: edit_id, token: token) }.to raise_error(StandardError, response_error_body.to_s)
      end
    end
  end

  describe '#update_listings' do
    let(:app_id) { 'app_id' }
    let(:edit_id) { 'edit_id' }
    let(:token) { 'token' }
    let(:version_code) { '1000000' }
    let(:skip_upload_changelogs) { false }
    let(:metadata_path) { './fastlane/metadata/android' }
    let(:lang_us) { 'en-US' }
    let(:lang_jp) { 'ja-JP' }
    let(:listings_url) { "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/listings" }
    let(:us_listings_url) { "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/listings/#{lang_us}" }
    let(:jp_listings_url) { "api/appstore/v1/applications/#{app_id}/edits/#{edit_id}/listings/#{lang_jp}" }
    let(:listings_response_body) do
      {
        listings: {
          'en-US': {
            language: lang_us,
            title: 'title',
            fullDescription: 'fullDescription',
            shortDescription: 'shortDescription',
            recentChanges: nil,
            featureBullets: ['featureBullets'],
            keywords: ['keywords']
          },
          'ja-JP': {
            language: lang_jp,
            title: 'title',
            fullDescription: 'fullDescription',
            shortDescription: 'shortDescription',
            recentChanges: nil,
            featureBullets: ['featureBullets'],
            keywords: ['keywords']
          }
        }
      }
    end
    let(:us_listings_response_body) do
      {
        language: lang_us,
        title: 'title',
        fullDescription: 'fullDescription',
        shortDescription: 'shortDescription',
        recentChanges: nil,
        featureBullets: ['featureBullets'],
        keywords: ['keywords']
      }
    end
    let(:jp_listings_response_body) do
      {
        language: lang_jp,
        title: 'title',
        fullDescription: 'fullDescription',
        shortDescription: 'shortDescription',
        recentChanges: nil,
        featureBullets: ['featureBullets'],
        keywords: ['keywords']
      }
    end
    let(:response_error_body) do
      {
        error_description: "Client authentication failed",
        error: "invalid_client"
      }
    end

    before do
      allow_any_instance_of(Faraday::Connection).to receive(:get).with(listings_url).and_return(
        double(Faraday::Response, status: 200, body: listings_response_body, success?: true, headers: { 'Etag' => 'AAAA' })
      )
      allow_any_instance_of(Faraday::Connection).to receive(:put).with(us_listings_url).and_return(
        double(Faraday::Response, status: 204, body: us_listings_response_body, success?: true)
      )
      allow_any_instance_of(Faraday::Connection).to receive(:put).with(jp_listings_url).and_return(
        double(Faraday::Response, status: 204, body: jp_listings_response_body, success?: true)
      )
    end

    context 'success' do
      it 'should not raise error' do
        expect(Fastlane::Helper::AmazonAppstoreHelper.update_listings(app_id: app_id, edit_id: edit_id, token: token, version_code: version_code, skip_upload_changelogs: skip_upload_changelogs, metadata_path: metadata_path)).to eq(nil)
      end
    end

    context 'failed to get listings' do
      it 'should raise error' do
        allow_any_instance_of(Faraday::Connection).to receive(:get).with(listings_url).and_return(
          double(Faraday::Response, status: 401, body: response_error_body, success?: false)
        )
        expect { Fastlane::Helper::AmazonAppstoreHelper.update_listings(app_id: app_id, edit_id: edit_id, token: token, version_code: version_code, skip_upload_changelogs: skip_upload_changelogs, metadata_path: metadata_path) }.to raise_error(StandardError, response_error_body.to_s)
      end
    end

    context 'failed to put listings' do
      it 'should raise error' do
        allow_any_instance_of(Faraday::Connection).to receive(:put).with(us_listings_url).and_return(
          double(Faraday::Response, status: 401, body: response_error_body, success?: false)
        )
        expect { Fastlane::Helper::AmazonAppstoreHelper.update_listings(app_id: app_id, edit_id: edit_id, token: token, version_code: version_code, skip_upload_changelogs: skip_upload_changelogs, metadata_path: metadata_path) }.to raise_error(StandardError, response_error_body.to_s)
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
