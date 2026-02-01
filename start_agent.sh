#!/bin/bash
cd "$(dirname "$0")"
dart run vcr_agent/bin/vcr_agent.dart -q "$@"
