// Normal builds have no built-in login; spike/build-with-login.ps1 swaps in source-local/LocalCredentials.mc for sideloaded builds.
(:no_local_login)
function localCredentials() {
    return null;
}
