# amazon_appstore `fastlane` plugin

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-amazon_appstore)
![](https://github.com/ntsk/fastlane-plugin-amazon_appstore/actions/workflows/test/badge.svg)

## Getting Started

This project is a [_fastlane_](https://github.com/fastlane/fastlane) plugin. To get started with `fastlane-plugin-amazon_appstore`, add it to your project by running:

```bash
fastlane add_plugin amazon_appstore
```

## About amazon_appstore

Upload the apk to the Amazon Appstore using the [App Submission API](https://developer.amazon.com/docs/app-submission-api/overview.html).

In the future, it would be nice to be able to use it to update store information like `upload_to_play_store`, but for now, it only supports replacing apk and submitting it for review.

## Usage

Following the [guide](https://developer.amazon.com/docs/app-submission-api/auth.html), you will need to generate `client_id` and `client_secret` to access the console in advance.

Call `upload_to_amazon_appstore` in your Fastfile.

```ruby
upload_to_amazon_appstore(
  apk: "app/build/outputs/apk/release/app-release.apk",
  client_id: <YOUR_CLIENT_ID>,
  client_secret: <YOUR_CLIENT_SECRET>
)
```

### Parameters
| Key                         | Description                                                                                                                                | Default                     | 
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------- | 
| package_name                | The package name of the application to use                                                                                                 | *                           | 
| apk                         | Path to the APK file to upload                                                                                                             | *                           | 
| client_id                   | The client ID you saved                                                                                                                    |                             | 
| client_secret               | The client secret you saved                                                                                                                |                             | 
| skip_upload_changelogs      | Whether to skip uploading changelogs                                                                                                       | false                       | 
| metadata_path               | Path to the directory containing the metadata files                                                                                        | ./fastlane/metadata/android | 
| changes_not_sent_for_reivew | Indicates that the changes in this edit will not be reviewed until they are explicitly sent for review from the Amazon Appstore Console UI | false                       | 
| timeout                     | Timeout for read, open (in seconds)                                                                                                        | 300                         | 
* = default value is dependent on the user's system

### Changelogs

You can update the release notes by adding a file under `changelogs/` in the same way as [supply](https://docs.fastlane.tools/actions/upload_to_play_store/).
The filename should exactly match the version code of the APK that it represents. You can also provide default notes that will be used if no files match the version code by adding a default.txt file. 

```
└── fastlane
    └── metadata
        └── android
            ├── en-US
            │   └── changelogs
            │       ├── default.txt
            │       ├── 100000.txt
            │       └── 100100.txt
            └── fr-FR
                └── changelogs
                    ├── default.txt
                    └── 100100.txt
```

One difference from Google Play is that the Amazon Appstore always requires release notes to be entered before review.
For this reason, `-` will be entered by default if the corresponding changelogs file is not found, or if the `skip_upload_changelogs` parameter is used.

## Run tests for this plugin

To run both the tests, and code style validation, run

```
rake
```

To automatically fix many of the styling issues, use
```
rubocop -a
```

## Issues and Feedback

For any other issues and feedback about this plugin, please submit it to this repository.

## Troubleshooting

If you have trouble using plugins, check out the [Plugins Troubleshooting](https://docs.fastlane.tools/plugins/plugins-troubleshooting/) guide.

## Using _fastlane_ Plugins

For more information about how the `fastlane` plugin system works, check out the [Plugins documentation](https://docs.fastlane.tools/plugins/create-plugin/).

## About _fastlane_

_fastlane_ is the easiest way to automate beta deployments and releases for your iOS and Android apps. To learn more, check out [fastlane.tools](https://fastlane.tools).
