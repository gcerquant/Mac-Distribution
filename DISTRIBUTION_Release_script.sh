#!/bin/bash
# 
# MacMation - http://www.macmation.com
# Guillaume Cerquant - contact at domainnameabove
# 
# 
# Based from http://www.entropy.ch/blog/Developer/2008/09/22/Sparkle-Appcast-Automation-in-Xcode.html
# 
# This script:
# enforces a Release build
# creates a .zip file of the application. You could also package up a .dmg with additional material.
# fetches the signing private key from the keychain. This step might pop up a dialog: 
# calculates the SHA1 checksum of the distribution file
# signs the checksum with the private key
# converts the signature to Base64
# emits an item block with all the information (date, size, version) about the update. You add this block to your appcast XML file.
# I also let it print out the scp commands required to publish the update.


PROJECT_NAME="ProjectName"


echo "Project name is: $PROJECT_NAME"
set -o errexit

[ $BUILD_STYLE = Release ] || { echo Distribution target requires "'Release'" build style; false; }


VERSION=$(defaults read "$BUILT_PRODUCTS_DIR/$PROJECT_NAME.app/Contents/Info" CFBundleVersion)
DOWNLOAD_BASE_URL="http://www.yourserver.com/download"
RELEASENOTES_URL="http://www.yourserver.com/ReleaseNotes#version-$VERSION"

ARCHIVE_FILENAME="$PROJECT_NAME"'_v'"$VERSION.dmg"

echo "archive file name is: $ARCHIVE_FILENAME"
DOWNLOAD_URL="$DOWNLOAD_BASE_URL/$ARCHIVE_FILENAME"
KEYCHAIN_PRIVKEY_NAME="YourProduct Sparkle Private Key"

WD=$PWD
cd "$BUILT_PRODUCTS_DIR"

temp_dir=`/usr/bin/mktemp -dq /tmp/TimeBoxed_XXXXXXXXXXXX`
if [ $? -ne 0 ]; then
	echo "$0: Can't create temp file, exiting..."
    exit 1
fi


# Copy the application into the futur image disk folder
/bin/cp -f -R "$PROJECT_NAME.app" $temp_dir

# Copy other resources into the futur image disk folder
/bin/cp -f -R "$SRCROOT/resources_for_DMG/" $temp_dir

# Move the hand-made .DS_Store to have the right position and background image
/bin/mv -f "$temp_dir/DMG-DS_Store" $temp_dir/.DS_Store

# Set the background image file as invisible
/Developer/Tools/SetFile -a V $temp_dir/DMG_background.png





/usr/bin/hdiutil create "$ARCHIVE_FILENAME" -srcfolder "$temp_dir" -ov -volname "NameOfDMGVolume" 

# Setting the custom icon for the DMG

~/bin/setFileIcon $ARCHIVE_FILENAME "$SRCROOT/resources_to_build_DMG/DMG_icon.icns"


# DMG has been created




SIZE=$(stat -f %z "$ARCHIVE_FILENAME")
PUBDATE=$(date +"%a, %d %b %G %T %z")
SIGNATURE=$(
	openssl dgst -sha1 -binary < "$ARCHIVE_FILENAME" \
	| openssl dgst -dss1 -sign <(security find-generic-password -g -s "$KEYCHAIN_PRIVKEY_NAME" 2>&1 1>/dev/null | perl -pe '($_) = /"(.+)"/; s/\\012/\n/g') \
	| openssl enc -base64
)

[ $SIGNATURE ] || { echo Unable to load signing private key with name "'$KEYCHAIN_PRIVKEY_NAME'" from keychain; false; }

echo "--------------------------"
echo ""
echo "Add this to the appcast:"
echo ""

cat <<EOF
		<item>
			<title>Version $VERSION</title>
			<sparkle:releaseNotesLink>$RELEASENOTES_URL</sparkle:releaseNotesLink>
			<pubDate>$PUBDATE</pubDate>
			<enclosure
				url="$DOWNLOAD_URL"
				sparkle:version="$VERSION"
				type="application/octet-stream"
				length="$SIZE"
				sparkle:dsaSignature="$SIGNATURE"
			/>
		</item>
EOF

# Textmate syntax color gets confused without this '


echo ""
echo "--------------------------"

BZR="/usr/local/bin/bzr"

cd "$SRCROOT"

last_tag=`$BZR tags --sort=time | tail -n1 | cut -d' ' -f1`

echo "Here are the release notes (since tag $last_tag):"


$BZR log -r tag:$last_tag..
$BZR log -r tag:$last_tag.. | mate -a


open "/Users/user_name/builds/Release"
