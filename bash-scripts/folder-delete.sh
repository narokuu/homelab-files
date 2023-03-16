#!/usr/bin/env bash

path="{{ rm_path }}"
maxsize=50000 # Value in KB

if (( "$(du -s "$path" | awk '{print $1}')" <= $maxsize )); then 
  rm -rfv "$path"
fi