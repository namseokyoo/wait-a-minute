#!/bin/bash
set -e

echo "🚀 Starting Flutter Web build for Vercel..."

# Check if Flutter is available
if ! command -v flutter &> /dev/null; then
    echo "📥 Installing Flutter..."
    git clone https://github.com/flutter/flutter.git -b stable --depth 1 /tmp/flutter
    export PATH="$PATH:/tmp/flutter/bin"
    flutter doctor --suppress-analytics
    flutter precache --web
fi

# Enable web support
flutter config --enable-web

# Install dependencies
echo "📦 Installing Flutter dependencies..."
flutter pub get

# Build web version
echo "🔨 Building Flutter web app..."
flutter build web --release --web-renderer canvaskit

echo "✅ Flutter web build completed successfully!"
echo "🎉 Ready for deployment!"