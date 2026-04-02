#!/usr/bin/env nu

def main [] {
    # Run from the repository root.
    ^v fmt -w src tests
    ^v -d mbedtls_client_read_timeout_ms=100000 src/main.v
}
