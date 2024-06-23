#!/bin/bash
## weather.sh
##   Shell script to fetch wttr weather/forecast data and format it 
##   to 50 x 15 characters to fit on Beepy screen with 8x16 fonts.
##
## v0.04 by TheMediocritist 20230830

# Default values
DEFAULT_LOCATION=Palo+Alto
DEFAULT_UNITS=imperial
CONFIG_FILE="$HOME/.config/weather.cfg"
PAGE=0

function clear_screen() {
  clear >$(tty)
}

function initialise() {
  
  clear_screen
  
  # Disable cursor
  printf "\033[?25l"
  
  # Disable line wrapping.
  printf '\e[?7l'
  
  # Check if the configuration file exists, otherwise create it
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "location=$DEFAULT_LOCATION" > "$CONFIG_FILE"
    echo "units=$DEFAULT_UNITS" >> "$CONFIG_FILE"
  fi
  
  # Read the configuration file and populate variables
  if [[ -f "$CONFIG_FILE" ]]; then
    while IFS='=' read -r key value; do
      if [[ -n $key && -n $value ]]; then
        case $key in
          location) location=$value ;;
          units) units=$value ;;
        esac
      fi
    done < "$CONFIG_FILE"
  fi
  
  # Substitute 'u' and 'm' for weather units
  if [[ $units == "imperial" ]]; then
    units_short="u"
  elif [[ $units == "metric" ]]; then
    units_short="m"
  fi
  
  fetch_data
  
}

function set_location_units() {

  clear_screen
  
  # Enable cursor
  printf "\033[?25h"
  
  # Prompt user to overwrite configuration settings
  echo "Enter location and units."
  echo "Format   : <location> <metric/imperial>"
  echo "Currently: $location $units"
  read -p "Change to: " new_location new_units
  
  # Update variables if user provides input
  if [[ -n $new_location ]]; then
    location=$new_location
  fi
  if [[ -n $new_units ]]; then
    units=$new_units
  fi
  
  # Update configuration file with new values
  echo "location=$location" > "$CONFIG_FILE"
  echo "units=$units" >> "$CONFIG_FILE"
  
  # Substitute 'u' and 'm' for weather units
  if [[ $units == "imperial" ]]; then
    units_short="u"
  elif [[ $units == "metric" ]]; then
    units_short="m"
  fi
  
  # Disable cursor
  printf "\033[?25l"
  
  PAGE=0
  
}

function toggle_units() {

  if [[ $units == "imperial" ]]; then
    units="metric"
    units_short="m"
  else
    units="imperial"
    units_short="u"
  fi
  
  # Update configuration file with new units
  echo "location=$location" > "$CONFIG_FILE"
  echo "units=$units" >> "$CONFIG_FILE"
  
  # Refresh data with the new units
  fetch_data
  
}

function reset_buffer() {
  # Set up a screen buffer
  screenbuffer=("                          [            ]        /3" \
                "                 ┌─── Morning ───┬──── Noon ─────┐" \
                "                 │               │               │" \
                "                 │               │               │" \
                "                 │               │               │" \
                "                 │               │               │" \
                "                 │               │               │" \
                "                 │               │               │" \
                "                 ├── Afternoon ──┼──── Night ────┤" \
                "                 │               │               │" \
                "                 │               │               │" \
                "                 │               │               │" \
                "                 │               │               │" \
                "                 │               │               │" \
                "                 └───────────────┴───────────────┘" \
                "(q)uit, (s)etup, (u)nits                          ")
}

# Helper function for padding/trimming string to desired length
function pad() {
  local text="$1"
  local length="$2"

  if [[ ${#text} -gt $length ]]; then
    printf "%s" "${text:0:$length}"
  else
    printf "%-${length}s" "$text"
  fi
}

function insertString() {
  local string=$1
  local row=$2
  local col=$3
  local tmp_line=${screenbuffer[$row]}

  # Calculate the length of the string
  local string_length=${#string}
  local col_end=$((col + string_length))

  # Insert the string into the buffer at the specified position
  tmp_line="${tmp_line:0:$col}$string${tmp_line:$col_end}"

  # Update the screenbuffer array with the modified line
  screenbuffer[$row]=$tmp_line
}

# Function to handle key press
function handleKeyPress() {
  local key=$1
  if [[ $key == "q" ]]; then # Exit the script if 'q' is pressed
    # Enable cursor
    printf "\033[?25h"
    # Enable line wrapping.
    printf '\e[?7h'
    clear_screen
    exit 0
  elif [[ $key == "s" ]]; then # Enter the settings screen
    set_location_units
    fetch_data
  elif [[ $key == "u" ]]; then # Toggle units between metric and imperial
    toggle_units
    fetch_data
  else
    # Increment PAGE variable and reset to 1 if it reaches 3
    ((PAGE++))
    if ((PAGE > 2)); then
      PAGE=0
    fi

  fi
}

function fetch_data() {
  
  # Disable cursor
  printf "\033[?25l"
  
  # Display loading screen
  clear_screen
  for i in $(seq 0 6); do 
    echo "" 
  done
  echo "                    loading..."
  
  # Fetch data from wttr.in
  readarray aWeather < <(curl wttr.in/$location?T?$units_short --silent --max-time 5)

  # Strip newlines from data
  weather_data=()
  for line in "${aWeather[@]}"; do
    weather_data+=("${line%$'\n'}")
  done
  
  location="${weather_data[0]:16:21}"
  location="${location//+/' '}"
  
  icon_array=("${weather_data[2]:3:13}" \
              "${weather_data[3]:3:13}" \
              "${weather_data[4]:3:13}" \
              "${weather_data[5]:3:13}" \
              "${weather_data[6]:3:13}")
  
  now_array=("${weather_data[2]:16:13}" \
             "${weather_data[3]:16:13}" \
             "${weather_data[4]:16:13}" \
             "${weather_data[5]:16:13}" \
             "${weather_data[6]:16:13}")
}

function fill_data() {

  insertString "$location" 6 3
  insertString "$((PAGE + 1))" 0 47

  for i in $(seq 0 4); do
      insertString "${icon_array[i]}" $((1+i)) 2
      insertString "${now_array[i]}" $((8+i)) 2
  done

  day="${weather_data[8+PAGE*10]:58:10}"

  insertString "$day" $((0)) 28

  am_array=()
  noon_array=()
  pm_array=()
  night_array=()

  for i in $(seq 0 4); do
    am_array+=(   "${weather_data[11+i+PAGE*10]:16:14}")
    noon_array+=( "${weather_data[11+i+PAGE*10]:47:14}")
    pm_array+=(   "${weather_data[11+i+PAGE*10]:78:14}")
    night_array+=("${weather_data[11+i+PAGE*10]:109:14}")
  done

  for i in $(seq 0 4); do
      insertString "${am_array[i]}" $((2+i)) 19
      insertString "${noon_array[i]}" $((2+i)) 35
      insertString "${pm_array[i]}" $((9+i)) 19
      insertString "${night_array[i]}" $((9+i)) 35
  done
}

function draw_buffer() {

  clear_screen

  # Print the screenbuffer (last line without newline to prevent scrolling)
  for i in $(seq 0 15); do
      echo "${screenbuffer[i]}"
  done
  echo -n "${screenbuffer[15]}"
}

# Main loop
initialise
while :
do
  reset_buffer
  fill_data
  draw_buffer

  # Pause until input
  read -rsn1 key
  handleKeyPress "$key"

done
