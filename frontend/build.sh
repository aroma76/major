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

# Move the built files to a 'public' directory
# Vercel automatically serves the 'public' directory if Output Directory is not set!
echo "Copying build/web to public directory for Vercel..."
rm -rf public
mkdir -p public
cp -r build/web/* public/

echo "Build and copy completed successfully!"
