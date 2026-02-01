#!/bin/bash
cd "$(dirname "$0")/vcr_agent" && dart run bin/vcr_agent.dart "$@"
