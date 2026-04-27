#!/bin/bash

echo "Starting Flutter Web build for Vercel..."

# Check if Flutter SDK exists, clone if not
if [ ! -d "flutter" ]; then
  echo "Cloning Flutter SDK..."
  git clone https://github.com/flutter/flutter.git -b stable
else
  echo "Flutter SDK already exists."
fi

# Add Flutter to the PATH
export PATH="$PATH:`pwd`/flutter/bin"

# Precache flutter to speed up builds
flutter precache

# Get dependencies
flutter pub get

# Build the web app
flutter build web --release

echo "Build completed successfully!"
