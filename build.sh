#!/bin/bash

# Build script for Speech Widget
echo "Building Speech Widget..."

swiftc SpeechWidget_final_backup.swift -o SpeechWidget \
    -framework Cocoa \
    -framework AVFoundation \
    -framework Carbon \
    -framework ApplicationServices

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "Run with: ./SpeechWidget &"
else
    echo "❌ Build failed!"
    exit 1
fi