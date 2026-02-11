#!/bin/bash
# Quick setup script for Play Store release

echo "🔐 Setting up release signing for Play Store..."
echo ""

# Check if keystore already exists
if [ -f ~/upload-keystore.jks ]; then
    echo "⚠️  Keystore already exists at ~/upload-keystore.jks"
    read -p "Do you want to create a new one? (y/N): " create_new
    if [ "$create_new" != "y" ]; then
        echo "Using existing keystore."
        exit 0
    fi
fi

# Create keystore
echo "Creating keystore..."
keytool -genkey -v -keystore ~/upload-keystore.jks \
    -keyalg RSA -keysize 2048 -validity 10000 -alias upload

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Keystore created successfully!"
    echo ""
    echo "Now create key.properties file:"
    echo "  cd android"
    echo "  cp key.properties.example key.properties"
    echo "  # Edit key.properties with your keystore password"
    echo ""
    echo "Then build release:"
    echo "  flutter build appbundle --release"
else
    echo "❌ Failed to create keystore"
    exit 1
fi
