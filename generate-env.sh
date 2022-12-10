source .env

EXAMPLE_ENV_FILENAME=".env.example"

cp .env tmp.env

# Replace FABI and JULIUS with JANE and JOHN
gsed -ri "s#$USER_1#JANE#g" tmp.env
gsed -ri "s#$USER_2#JOHN#g" tmp.env

# Replace hass device names
gsed -ri 's#(.*DEVICE.*=).*#\1"mobile_app"#g' tmp.env

# Redact tokens
gsed -ri 's#(.*TOKEN.*=).*#\1"12345678"#g' tmp.env

#Replace URLS
gsed -ri 's#(.*URL.*=).*#\1"https://example.com"#g' tmp.env

mv tmp.env $EXAMPLE_ENV_FILENAME
