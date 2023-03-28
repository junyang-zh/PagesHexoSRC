#!/bin/bash
set -ex

THEME_NEXT_PATH="node_modules/hexo-theme-next"
PISCES_STYL_FILE="$THEME_NEXT_PATH/source/css/_variables/Pisces.styl"

# Define the old and new lines to replace
OLD_LINE1='$border-radius-inner[[:blank:]]*= initial'
OLD_LINE2='$border-radius[[:blank:]]*= initial'
NEW_LINE1='$border-radius-inner   = 0 0 8px 8px'
NEW_LINE2='$border-radius         = 8px'

# Use sed to replace the lines in the file
sed -i -e "s/$OLD_LINE1/$NEW_LINE1/g" "$PISCES_STYL_FILE"
sed -i -e "s/$OLD_LINE2/$NEW_LINE2/g" "$PISCES_STYL_FILE"

# Place Artalk files
cp customization/artalk.js "$THEME_NEXT_PATH/scripts/filters/comment"
cp customization/artalk.njk "$THEME_NEXT_PATH/layout/_third-party/comments"
