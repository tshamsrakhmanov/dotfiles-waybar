#!/bin/bash

current_mute=$(pulsemixer --get-mute)

if [[ "$current_mute" == "0" ]]; then
  pulsemixer --mute
else
  pulsemixer --unmute
fi
