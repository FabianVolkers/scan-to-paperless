#! /bin/sh
# Adapted from https://support.brother.com/g/b/faqend.aspx?c=us&lang=en&prod=ads1500w_us&faqid=faq00100611_000

set +o noclobber
#
#   $1 = user to post document to
#

#  
#       100,200,300,400,600
#

source /opt/brother/scanner/brscan-skey/script/.env

# Scanner Options
SCANNER=$2
FRIENDLY_NAME=$3 # Could be read dynamically
RESOLUTION=600
# A4 Papersize
WIDTH=210
WIDTH_INCHES=8.268
HEIGHT=297
HEIGHT_INCHES=11.693
SCANNER_USER=$1

resolution=$RESOLUTION
device=$SCANNER

if [ "$SCANNER_USER" = 'fabi' ];then
    TOKEN=$PAPERLESS_TOKEN_FABI
    PAPERLESS_URL=$PAPERLESS_URL_FABI
    HASS_DEVICE=$HASS_DEVICE_FABI
elif [ "$SCANNER_USER" = 'julius' ];then
    TOKEN=$PAPERLESS_TOKEN_JULIUS
    PAPERLESS_URL=$PAPERLESS_URL_JULIUS
    HASS_DEVICE=$HASS_DEVICE_JULIUS
else
    echo "no user specified, aborting"
    exit 1
fi

# Ensure base dir exists
#BASE=~/brscan
BASE=/mnt/scanner/$SCANNER_USER
mkdir -p $BASE

if [ "`which usleep`" != ' ' ];then
    usleep 10000

else
    sleep  0.01
fi

# Set full path for tempfile
filename=$(date | sed s/' '/'_'/g | sed s/'\:'/'_'/g)
output_tmp=$BASE/$filename

# Scan pages
echo "scan from $2($device)"
scanadf --device-name "$device" --resolution $resolution -x $WIDTH -y $HEIGHT -o"$output_tmp"_%04d # user needs to be in lp group

# Convert images to PostScript
for pnmfile in $(ls "$output_tmp"*)
do
   echo pnmtops -dpi=$resolution -imagewidth=$WIDTH_INCHES -imageheight=$HEIGHT_INCHES -nocenter "$pnmfile"  "$pnmfile".ps
   pnmtops -dpi=$resolution -imagewidth=$WIDTH_INCHES -imageheight=$HEIGHT_INCHES -nocenter "$pnmfile"  > "$pnmfile".ps
   rm -f "$pnmfile"
done

# Merge individual PostScript files
echo psmerge -o"$output_tmp".ps  $(ls "$output_tmp"*.ps)
psmerge -o"$output_tmp".ps  $(ls "$output_tmp"*.ps)

# Convert PostScript file to PDF
echo ps2pdf "$output_tmp".ps   "$output_tmp".pdf
ps2pdf "$output_tmp".ps   "$output_tmp".pdf

# Remove PostScript files
for psfile in $(ls "$output_tmp"*.ps)
do
   rm $psfile
done
rm -f "$pnmfile".ps

# POST document to paperless
# https://docs.paperless-ngx.com/api/#file-uploads
# curl -X ...
echo curl -X POST -H "Content-Type:multipart/form-data" -H "Authorization: Token --REDACTED--" --form document=@"$output_tmp".pdf $PAPERLESS_URL/api/documents/post_document/
curl -X POST -H "Content-Type:multipart/form-data" -H "Authorization: Token ${TOKEN}" --form document=@"$output_tmp".pdf $PAPERLESS_URL/api/documents/post_document/
# Remove PDF from local disk (could be combined with other cleanup actions)

echo "Sending homeassistant notification\n"
notification_data=$(printf '{"title": "Scanning complete", "message": "%s.pdf"}' $filename)
curl -X POST -H "Authorization: Bearer $HASS_API_TOKEN -H "Content-Type: application/json" -d "$notification_data" $HASS_URL/api/services/notify/$HASS_DEVICE
echo "Done Scanning File\n"
