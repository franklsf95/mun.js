#!/bin/bash
cd "$(dirname "$0")"
open index.html -a "Google Chrome" --args --allow-file-access-from-files
open -a "CodeKit"