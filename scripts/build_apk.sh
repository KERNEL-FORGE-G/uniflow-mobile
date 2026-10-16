#!/bin/bash

# Build release APK
echo "Building release APK..."
flutter build apk --release

# Check if build was successful
if [ $? -eq 0 ]; then
  echo "Build successful!"
  echo "APK location: build/app/outputs/flutter-apk/app-release.apk"
else
  echo "Build failed."
  exit 1
fi
