#!/usr/bin/env nu

def main [] {
    # Run from the repository root.
    ^v fmt -w src tests
    ^v src/main.v
}
