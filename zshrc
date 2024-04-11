PROMPT="$fg[cyan]%}cyf-ubuntu ${PROMPT}"

function set_http_proxy(){
    export http_proxy='http://localhost:8118'
    export https_proxy='http://localhost:8118'
}

function unset_http_proxy(){
    unset http_proxy
    unset https_proxy
}
