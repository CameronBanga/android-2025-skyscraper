#!/bin/sh

#
# upload-symbols.sh
# Uploads dSYM files to Firebase Crashlytics
#

# Only run for release builds (not debug)
if [ "${CONFIGURATION}" != "Release" ]; then
  echo "Skipping Crashlytics symbol upload for non-Release build"
  exit 0
fi

# Find the upload-symbols script from Firebase Crashlytics
# This script is included with the Firebase iOS SDK via SPM
UPLOAD_SYMBOLS_PATH="${BUILD_DIR%Build/*}SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/upload-symbols"

if [ ! -f "$UPLOAD_SYMBOLS_PATH" ]; then
  echo "Error: Could not find upload-symbols script at: $UPLOAD_SYMBOLS_PATH"
  echo "Make sure Firebase Crashlytics is properly installed via Swift Package Manager"
  exit 1
fi

echo "Found upload-symbols at: $UPLOAD_SYMBOLS_PATH"

# Upload symbols
"$UPLOAD_SYMBOLS_PATH" -gsp "${PROJECT_DIR}/Skyscraper/GoogleService-Info.plist" -p ios "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}"

echo "Crashlytics symbols uploaded successfully"
