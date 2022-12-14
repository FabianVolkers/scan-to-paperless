#!/usr/bin/env bash
# Adapted from https://support.brother.com/g/b/faqend.aspx?c=us&lang=en&prod=ads1500w_us&faqid=faq00100611_000

set +o noclobber
#
#   $1 = Selected Scanner Option (OCR,FILE,IMAGE,EMAIL)
#   $2 = Device name
#   $3 = Friendly device name
#  #

echo "Begin scan from option $1"

# Set working directory
script_relative_dir=$(dirname "${BASH_SOURCE[0]}") 
cd "$script_relative_dir" || exit

# Check if required packages are installed
required_packages=(scanadf pnmtops psmerge ps2pdf pdftk bc)
for package in "${required_packages[@]}"
do
    if [ "$(which "$package")" == '' ];then
        echo "command $package not found"
        echo "Packages sane, netpbm, pdftk, ghostscript, bc need to be installed"
        # Stop executing
    fi
done

num_cores=$(grep -c processor /proc/cpuinfo)

# CONSTANTS
# Papersizes in millimeter
# A4 Papersize
# shellcheck disable=SC2034
A4_WIDTH=210
# shellcheck disable=SC2034
A4_HEIGHT=297

if [ "$(find ./.env)" != '' ];then
    echo Loading user config from "$PWD"/.env
    # shellcheck source=.env
    source .env
else
    echo .env file not found at "$PWD"/.env
    echo "Unable to load config, aborting"
fi

# Read Arguments
device=$2
friendly_name=$3

papersize_width_var="$PAPERSIZE"_WIDTH
papersize_height_var="$PAPERSIZE"_HEIGHT

WIDTH=${!papersize_width_var}
WIDTH_INCHES=$(echo "$WIDTH * 0.03937008" | bc)
HEIGHT=${!papersize_height_var}
HEIGHT_INCHES=$(echo "$HEIGHT * 0.03937008" | bc)


# Set scanner mode and user from argument
IFS=' '
read -ra mode_user_args <<< "${!1}"
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

# Ensure base dir exists
base=$SCANNER_BASE_DIR/$scanner_user
if [ "$scanner_mode" == 'duplex' ];then
  base="$base/duplex"
fi
mkdir -p "$base"

if [ "$(which usleep)" != '' ];then
    usleep 10000

else
    sleep  0.01
fi

# Set full path for tempfile
timestamp=$(date "+%Y_%m_%d__%H_%M_%S")
filename=$timestamp
output_tmp=$base/$filename

# Scan pages
echo "scan from $friendly_name($device)"
echo scanadf --device-name "$device" --resolution "$RESOLUTION" -x "$WIDTH" -y "$HEIGHT" -o "$output_tmp"_%04d.pbm
scanadf --device-name "$device" --resolution "$RESOLUTION" -x "$WIDTH" -y "$HEIGHT" -o "$output_tmp"_%04d.pbm # user needs to be in lp group

# Convert images to PostScript
echo "Convert images to PostScript"
pnmtops_pids=()
for pnmfile in "$output_tmp"*.pbm
do
   # shellcheck disable=SC2001
   psfile=$(echo "$pnmfile" | sed 's/\.pbm$/\.ps/')
   echo pnmtops -dpi="$RESOLUTION" -imagewidth="$WIDTH_INCHES" -imageheight="$HEIGHT_INCHES" -nocenter "$pnmfile"  "$psfile"
   pnmtops -dpi="$RESOLUTION" -imagewidth="$WIDTH_INCHES" -imageheight="$HEIGHT_INCHES" -nocenter "$pnmfile"  > "$psfile" &
   pnmtops_pids+=(${!})
done

for pnmtops_pid in "${pnmtops_pids[@]}"
do
  wait "${pnmtops_pid}"
done

rm -f "$output_tmp"*.pbm

# Merge individual PostScript files
echo "Merge individual PostScript files"
read -ra psfiles < <(find "$output_tmp"*.ps | tr '\n' ' ')
echo psmerge -o"$output_tmp".ps "${psfiles[@]}"
psmerge -o"$output_tmp".ps "${psfiles[@]}"

# Convert PostScript file to PDF
echo "Convert PostScript file to PDF"
echo ps2pdf -dNumRenderingThreads="$num_cores" "$output_tmp".ps   "$output_tmp".pdf
ps2pdf -dNumRenderingThreads="$num_cores" "$output_tmp".ps   "$output_tmp".pdf

# Remove PostScript files

echo "Removing PostScript files"
echo rm "$output_tmp"*.ps
rm "$output_tmp"*.ps

#######################
### DUPLEX SCANNING ###
#######################

if [ "$scanner_mode" == 'duplex' ];then
   ready_to_upload=false
   if [ "$(find "$base"/*.pdf | wc -l)" -gt 1 ];then
     output_tmp="$output_tmp"_merged
     filename="$filename"_merged
     ODD=$(find "$base"/* | head -n1)
     EVEN=$(find "$base"/* | head -n2 | tail -n1)
     echo "Merging odd $ODD and even $EVEN page numbers"
     echo pdftk A="$ODD" B="$EVEN" shuffle A Bend-1south output "$output_tmp".pdf
     pdftk A="$ODD" B="$EVEN" shuffle A Bend-1south output "$output_tmp".pdf
     ready_to_upload=true
  fi
else
  ready_to_upload=true
fi

######################

if [ "$ready_to_upload" == true ];then
  # POST document to paperless
  # https://docs.paperless-ngx.com/api/#file-uploads
  echo curl -s -X POST -H "Content-Type:multipart/form-data" -H "Authorization: Token --REDACTED--" --form document=@"$output_tmp".pdf "$paperless_url"/api/documents/post_document/
  curl -s -X POST -H "Content-Type:multipart/form-data" -H "Authorization: Token ${paperless_token}" --form document=@"$output_tmp".pdf "$paperless_url"/api/documents/post_document/

  if [ "$scanner_mode" == 'duplex' ];then
    echo "Moving merged file to $base/../"
    mv "$output_tmp".pdf "$base"/../

    # Remove merged PDFs from local disk
    echo rm "$base"/*.pdf
    rm "$base"/*.pdf
  fi
fi

echo "Sending homeassistant notification to $hass_device"
notification_data=$(printf '{"title": "Scanning complete", "message": "%s.pdf"}' "$filename")
curl -s -X POST -H "Authorization: Bearer $HASS_API_TOKEN" -H "Content-Type: application/json" -d "$notification_data" "$HASS_URL"/api/services/notify/"$hass_device"
echo "Done Scanning File"
