#!/usr/bin/env bash
# Adapted from https://support.brother.com/g/b/faqend.aspx?c=us&lang=en&prod=ads1500w_us&faqid=faq00100611_000

set +o noclobber
#
#   $1 = Selected Scanner Option (OCR,FILE,IMAGE,EMAIL)
#   $2 = Device name
#   $3 = Friendly device name
#  #

echo "Begin scan from option $1"

echo "Loading config from /opt/brother/scanner/brscan-skey/script/.env"
source /opt/brother/scanner/brscan-skey/script/.env

# Read Arguments
SCANNER=$2
FRIENDLY_NAME=$3 # Could be read dynamically

# Papersizes in millimeter
# A4 Papersize
A4_WIDTH=210
A4_HEIGHT=297

papersize_width_var="$PAPERSIZE"_WIDTH
papersize_height_var="PAPERSIZE"_HEIGHT

WIDTH=${!papersize_width_var}
WIDTH_INCHES=$WIDTH * 25.4
HEIGHT=${!papersize_height_var}
HEIGHT_INCHES=$HEIGHT * 25.4

# Check if required packages are installed
required_packages=(scanadf pnmtops psmerge ps2pdf pdftk)
for package in "${required_packages[@]}"
do
    if [ "`which $package`" == '' ];then
        echo "command $package not found"
        echo "Packages sane, netpbm, pdftk, ghostscript need to be installed"
    fi
done

# Set scanner mode and user from argument
IFS=' '
read -ra mode_user_args <<< ${!1}
scanner_mode=${mode_user_args[0]}
scanner_user=${!mode_user_args[1]}

echo "Scanning $scanner_mode for user $scanner_user"

# Construct variable names from scanner_user
paperless_token_var="PAPERLESS_TOKEN_$scanner_user"
paperless_url_var="PAPERLESS_URL_$scanner_user"
hass_device_var="HASS_DEVICE_$scanner_user"

# Set variables based on user
paperless_token=${!paperless_token_var}
paperless_url=${!paperless_url_var}
hass_device=${!hass_device_var}

#SCANNER_USER=$1

resolution=$RESOLUTION
device=$SCANNER

if [ "$scanner_mode" == 'simplex' ];then
   ready_to_upload=true
else
   ready_to_upload=false
fi

# Ensure base dir exists
#BASE=~/brscan
BASE=$SCANNER_BASE_DIR/$scanner_user
if [ "$scanner_mode" == 'duplex' ];then
  BASE="$BASE/duplex"
fi
mkdir -p $BASE

if [ "`which usleep`" != '' ];then
    usleep 10000

else
    sleep  0.01
fi

# Set full path for tempfile
timestamp=$(date "+%Y_%m_%d__%H_%M_%S")
filename=$timestamp
output_tmp=$BASE/$filename

# Scan pages
echo "scan from $FRIENDLY_NAME($device)"
scanadf --device-name "$device" --resolution $resolution -x $WIDTH -y $HEIGHT -o"$output_tmp"_%04d # user needs to be in lp group

# Convert images to PostScript
echo "Convert images to PostScript"
for pnmfile in $(ls "$output_tmp"*)
do
   echo pnmtops -dpi=$resolution -imagewidth=$WIDTH_INCHES -imageheight=$HEIGHT_INCHES -nocenter "$pnmfile"  "$pnmfile".ps
   pnmtops -dpi=$resolution -imagewidth=$WIDTH_INCHES -imageheight=$HEIGHT_INCHES -nocenter "$pnmfile"  > "$pnmfile".ps
   rm -f "$pnmfile"
done

# Merge individual PostScript files
echo "Merge individual PostScript files"
echo psmerge -o"$output_tmp".ps  $(ls "$output_tmp"*.ps)
psmerge -o"$output_tmp".ps  $(ls "$output_tmp"*.ps)

# Convert PostScript file to PDF
echo "Convert PostScript file to PDF"
echo ps2pdf "$output_tmp".ps   "$output_tmp".pdf
ps2pdf "$output_tmp".ps   "$output_tmp".pdf

# Remove PostScript files

echo "Removing PostScript files"
echo rm "$output_tmp"*.ps
rm "$output_tmp"*.ps

#######################
### DUPLEX SCANNING ###
#######################

if [ "$scanner_mode" == 'duplex' ];then
   echo "Duplex scanning"
   if [ "`ls $BASE/*.pdf | wc -l`" -gt 1 ];then
     output_tmp="$output_tmp"_merged
     filename="$filename"_merged
     ODD=$(ls $BASE/* | head -n1)
     EVEN=$(ls $BASE/* | head -n2 | tail -n1)
     echo "Merging odd $ODD and even $EVEN page numbers"
     echo pdftk A=$ODD B=$EVEN shuffle A Bend-1south output "$output_tmp".pdf
     pdftk A=$ODD B=$EVEN shuffle A Bend-1south output "$output_tmp".pdf
     ready_to_upload=true
  fi
fi

######################

if [ "$ready_to_upload" == true ];then
  # POST document to paperless
  # https://docs.paperless-ngx.com/api/#file-uploads
  echo curl -X POST -H "Content-Type:multipart/form-data" -H "Authorization: Token --REDACTED--" --form document=@"$output_tmp".pdf $paperless_url/api/documents/post_document/
  curl -X POST -H "Content-Type:multipart/form-data" -H "Authorization: Token ${paperless_token}" --form document=@"$output_tmp".pdf $paperless_url/api/documents/post_document/

  if [ "$scanner_mode" == 'duplex' ];then
    echo "Moving merged file to $BASE/../"
    mv "$output_tmp".pdf $BASE/../

    #Remove PDF from local disk
    echo rm $BASE/*.pdf
    rm $BASE/*.pdf
  fi
fi

echo "Sending homeassistant notification to $hass_device\n"
notification_data=$(printf '{"title": "Scanning complete", "message": "%s.pdf"}' $filename)
curl -X POST -H "Authorization: Bearer $HASS_API_TOKEN" -H "Content-Type: application/json" -d "$notification_data" $HASS_URL/api/services/notify/$hass_device
echo "Done Scanning File\n"
