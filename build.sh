#!/bin/bash

# Vercel Build Script for Flutter Web
echo "🚀 Starting Flutter Web build for Vercel..."

# Install Flutter dependencies
echo "📦 Installing Flutter dependencies..."
flutter pub get

# Build web version
echo "🔨 Building Flutter web app..."
flutter build web --release --web-renderer canvaskit

# Ensure the build was successful
if [ -d "build/web" ]; then
    echo "✅ Flutter web build completed successfully!"
    echo "📁 Build output directory: build/web"
    ls -la build/web/
else
    echo "❌ Flutter web build failed!"
    exit 1
fi

echo "🎉 Ready for Vercel deployment!"