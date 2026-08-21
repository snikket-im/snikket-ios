# Snikket iOS client

This is the source code for the Snikket iOS client.

## Command-line development and TestFlight

`./scripts/snikket help` lists all commands. The daily loop:

```sh
./scripts/snikket run    # build, install, and launch in a simulator
                         # (the first run also downloads dependencies)
./scripts/snikket logs   # stream the app's logs
```

The release commands need App Store Connect API credentials: copy
`.env.example` to the ignored `.env.local` and fill it in. Shipping a beta:

```sh
./scripts/snikket doctor
./scripts/snikket release status
./scripts/snikket version set 1.2.6
git commit -am "Bump version to 1.2.6" && git push
./scripts/snikket release publish    # requires a clean tree
```

The marketing version lives in `Config/Version.xcconfig`; change it with
`version set`, never in Xcode's target editor. Build numbers are picked
automatically on release.

# License

Snikket for iOS is based on [Siskin IM](https://siskin.im/) by <a href="https://tigase.net/"><img alt="Tigase Tigase Logo" src="https://github.com/tigase/website-assets/blob/master/tigase/images/tigase-logo.png?raw=true" width="25"/> Tigase</a>.

The official Siskin IM repository is available at: https://github.com/tigase/siskin-im/

Copyright (c) 2004 Tigase, Inc. and Snikket Community Interest Company.

Snikket and the Snikket logo are trademarks of Snikket Community Interest Company.

Licensed under GPL License Version 3.
