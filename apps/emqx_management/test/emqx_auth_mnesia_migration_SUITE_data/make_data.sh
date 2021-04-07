#!/bin/bash
set -eux pipefail
# Helper script for creating data export files

container() {
    version="${1}"
    docker rm -f emqx || true
    docker run emqx/emqx:$version true # Make sure the image is cached locally
    docker run --rm -e EMQX_LOADED_PLUGINS="emqx_auth_mnesia emqx_auth_clientid emqx_management" \
           --name emqx -p 8081:8081 emqx/emqx:$version emqx foreground &
    sleep 7
}

create_acls () {
    url="${1}"
    curl -f -v "http://localhost:8081/$url" -u admin:public -d@- <<EOF
[
  {
    "login":"emqx_c",
    "topic":"Topic/A",
    "action":"pub",
    "allow": true
  },
  {
    "login":"emqx_c",
    "topic":"Topic/A",
    "action":"sub",
    "allow": true
  }
]
EOF
}

create_user () {
    url="${1}"
    curl -f -v "http://localhost:8081/api/v4/$url" -u admin:public -d@- <<EOF
{
    "login": "emqx_c",
    "password": "emqx_p",
    "is_superuser": true
}
EOF
}

export_data() {
    filename="${1}"

    docker exec emqx emqx_ctl data export
    docker exec emqx sh -c 'cat data/*.json' | jq > "$filename.json"
    cat "${filename}.json"
}

collect_4_2 () {
    container "4.2.9"
    create_acls "api/v4/mqtt_acl"
    create_user mqtt_user

    # Add clientid
    docker exec emqx emqx_ctl clientid add emqx_clientid emqx_p

    export_data "v4.2.9"
}

collect_4_1 () {
    container "v4.1.5"
    create_acls "api/v4/emqx_acl"
    create_user auth_user

    # Add clientid
    docker exec emqx emqx_ctl clientid add emqx_clientid emqx_p

    export_data "v4.1.5"
}

collect_4_0 () {
    container "v4.0.7"

    # Add clientid
    docker exec emqx emqx_ctl clientid add emqx_clientid emqx_p

    export_data "v4.0.7"
}

collect_4_0
collect_4_1
collect_4_2

docker kill emqx
