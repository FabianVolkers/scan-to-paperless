# Scan to Paperless

This repo contains code to use scanadf to scan to paperless. It was originally created to use a Brother MFC-L2710DN and its scan button but should work on other models with the correct drivers installed.

## Manual Installation

Put the files in the right locations

- `brscan-skey.config` at `/opt/brother/scanner/brscan-skey/brscan-skey.config`
- `scantopaperless.sh` at /opt/brother/scanner/brscan-skey/script/scantopaperless.sh`
- `.env` at /opt/brother/scanner/brscan-skey/script/.env`

## Brother Drivers

### Patch to install

https://support.brother.com/g/b/faqend.aspx?c=eu_ot&lang=en&prod=mfcl2710dn_eu&ftype3=100258&faqid=faq00100729_000

### Stackoverflow Troubleshooting Thread

https://askubuntu.com/questions/389636/invalid-argument-brother-scanner-not-working-after-upgrade-brscan2-driver

