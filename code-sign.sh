#!/bin/bash
  cd ./frontend/appflowy_flutter/product/0.9.4/macos/Release/

  echo "🔧 Signing frameworks..."
  find AppFlowy.app/Contents/Frameworks -name "*.framework" -exec codesign --force --deep --sign - {} \;
  find AppFlowy.app/Contents/Frameworks -name "*.dylib" -exec codesign --force --sign - {} \;

  echo "🔧 Signing main app..."
  codesign --force --deep --sign - AppFlowy.app

  echo "✅ Verifying signature..."
  codesign --verify --deep --verbose=2 AppFlowy.app

  if [ $? -eq 0 ]; then
      echo "🎉 Code signing successful!"
      echo "📱 You can now run: open AppFlowy.app"
  else
      echo "❌ Code signing failed!"
  fi