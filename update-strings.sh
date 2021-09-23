if ! test -d Snikket/tmp.strings; then
  mkdir Snikket/tmp.strings;
fi

find ./Snikket -name "*.swift" -print0 | xargs -0 genstrings -o Snikket/tmp.strings
iconv -f utf-16 -t utf-8 Snikket/tmp.strings/Localizable.strings > Snikket/en.lproj/Localizable.strings
rm -rf Snikket/tmp.strings
