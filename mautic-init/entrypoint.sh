# VARS
# VOLUME_PATH string

# IF VOLUME PATH IS EMPTY THEN


if [ -z "$(ls -A $VOLUME_PATH)" ]; then
  echo "moving themes to $VOLUME_PATH"
  mv ./themes/* ${VOLUME_PATH}
else
   echo "directory is not empty"
fi