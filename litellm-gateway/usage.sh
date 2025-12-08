#!/bin/bash
grep "total_tokens" logs/litellm.log | tail -n 30
