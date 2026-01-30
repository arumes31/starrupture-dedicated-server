#!/bin/bash

echo " "
echo "Startup"
echo " "

# Check available disk space
echo "Checking available disk space..."
df -h /home/container/server_files
echo " "

server_files="/home/container/server_files"
echo "server path: $server_files"
mkdir -p "$server_files"
savegame_files="/home/container/server_files/StarRupture/Saved/SaveGames"
echo "savegame path: $savegame_files"

echo " "
echo "Installing Steam"
echo " "

steam_path=/home/container/steamcmd
steamcmd=$steam_path/steamcmd.sh

if [ ! -f "$steamcmd" ]; then
    mkdir -p $steam_path
    curl -sSL -o $steam_path/steamcmd.tar.gz https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz
    tar -xzf $steam_path/steamcmd.tar.gz -C $steam_path
    echo "Steam ... Installed"
else
    echo "Steam ... Already Installed"
fi

echo " "
echo "Installing/Updating StarRupture Dedicated Server files..."
echo " "

AUTO_UPDATE=${AUTO_UPDATE:-"true"}
VALIDATE_FILES=${VALIDATE_FILES:-"true"}

if [ "${AUTO_UPDATE}" == "true" ] || [ "${AUTO_UPDATE}" == "1" ]; then
    echo "Update enabled..."
    
    # Construct SteamCMD command using an array for safety
    cmd_flags=("$steamcmd" "+@sSteamCmdForcePlatformType" "windows" "+force_install_dir" "$server_files" "+login" "anonymous")
    
    if [ "${VALIDATE_FILES}" == "true" ] || [ "${VALIDATE_FILES}" == "1" ]; then
        echo "Validating files..."
        cmd_flags+=("+app_update" "3809400" "validate")
    else
        echo "Skipping validation..."
        cmd_flags+=("+app_update" "3809400")
    fi
    
    cmd_flags+=("+quit")
    
    # Run SteamCMD
    "${cmd_flags[@]}"
    exit_code=$?

    # Retry logic for exit code 8 (often corrupt manifest or disk space 0x202)
    if [ $exit_code -eq 8 ]; then
      echo " "
      echo "SteamCMD failed with exit code 8."
      echo "Common causes: Corrupt manifest (0x6) or Insufficient Disk Space (0x202)."
      echo "Checking disk space again:"
      df -h /home/container/server_files
      
      echo "Attempting to fix by removing appmanifest_3809400.acf and retrying (without explicit validation)..."
      rm -f "$server_files/steamapps/appmanifest_3809400.acf"
      
      # Retry without 'validate' keyword to be less aggressive, 
      # though missing manifest implies some checking.
      retry_flags=("${cmd_flags[@]}")
      # Remove 'validate' if it exists in the array
      for i in "${!retry_flags[@]}"; do
        if [[ "${retry_flags[i]}" == "validate" ]]; then
          unset 'retry_flags[i]'
        fi
      done
      
      echo "Retrying update..."
      "${retry_flags[@]}"
      exit_code=$?
    fi

    if [ $exit_code -ne 0 ]; then
      echo " "
      echo "SteamCmd failed with exit code: $exit_code"
      echo "Try deleting the appmanifest file or clear the whole server_files (installation only)"
      echo " "
      exit $exit_code
    else
      echo " "
      echo "SteamCmd finished successfully (Exit Code: $exit_code)"
      echo " "
    fi
else
    echo "Skipping update as requested (AUTO_UPDATE=${AUTO_UPDATE})"
fi

echo " "
echo "Configuring StarRupture Dedicated Server ..."
echo " "

USE_DSSETTINGS=${USE_DSSETTINGS:-"false"}
SERVER_PORT=${SERVER_PORT:-7777}
QUERY_PORT=${QUERY_PORT:-27015}
echo "Using Game Port: $SERVER_PORT"
echo "Using Query Port: $QUERY_PORT"

if [[ "${USE_DSSETTINGS}" == "true" ]] || [[ "${USE_DSSETTINGS}" == "1" ]]; then
  echo "DSSettings handling enabled."
  
  # Prepare DSSettings.txt from template
  cp "/home/container/scripts/DSSettings.txt" "$server_files/DSSettings.txt"

  # Update Password and PlayerPassword if env vars are set
  if [ -n "${SERVER_PASSWORD}" ]; then
    echo "Setting Server Password..."
    sed -i "s/\"Password\": \".*\"/\"Password\": \"${SERVER_PASSWORD}\"/" "$server_files/DSSettings.txt"
  fi
  if [ -n "${PLAYER_PASSWORD}" ]; then
    echo "Setting Player Password..."
    sed -i "s/\"PlayerPassword\": \".*\"/\"PlayerPassword\": \"${PLAYER_PASSWORD}\"/" "$server_files/DSSettings.txt"
  fi

  if [ -d "$savegame_files" ]; then
    # Priority: Check for user-specified 'SaveData.dat'
    # Find the most recently modified SaveData.dat recursively
    latest_dat_file=$(find "$savegame_files" -name "SaveData.dat" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -f2- -d" ")

    if [ -n "$latest_dat_file" ]; then
        echo "Found prioritized save file: $latest_dat_file"
        save_name=$(basename "$latest_dat_file")
        # Parent directory is assumed to be the SessionName
        session_dir=$(dirname "$latest_dat_file")
        session_name=$(basename "$session_dir")
        
        # Update SessionName and SaveGameName
        sed -i "s/\"SessionName\": \".*\"/\"SessionName\": \"$session_name\"/" "$server_files/DSSettings.txt"
        sed -i "s/\"SaveGameName\": \".*\"/\"SaveGameName\": \"$save_name\"/" "$server_files/DSSettings.txt"
        
        echo "DSSettings.txt updated with SaveData.dat."
        
    else
        # Fallback: Standard logic (find latest session folder, then latest .sav)
        latest_session_path=$(ls -td "$savegame_files"/*/ 2>/dev/null | head -n 1)

        if [ -n "$latest_session_path" ]; then
          # Remove trailing slash if present for basename
          latest_session_path="${latest_session_path%/}"
          session_name=$(basename "$latest_session_path")
          echo "Found latest session folder: $session_name"
          
          # Find the latest .sav file inside this session
          latest_save_file=$(ls -t "$latest_session_path"/*.sav 2>/dev/null | head -n 1)
          
          if [ -n "$latest_save_file" ]; then
            save_name=$(basename "$latest_save_file")
            echo "Found latest save file: $save_name"
            
            # Update SessionName and SaveGameName
            sed -i "s/\"SessionName\": \".*\"/\"SessionName\": \"$session_name\"/" "$server_files/DSSettings.txt"
            sed -i "s/\"SaveGameName\": \".*\"/\"SaveGameName\": \"$save_name\"/" "$server_files/DSSettings.txt"
            
            echo "DSSettings.txt updated with .sav file."
          else
            echo "No .sav files found in session '$session_name'. Cannot configure resume."
          fi
        else
          echo "No savegame session folders found."
        fi
    fi
  else
    echo "Savegame directory does not exist yet: $savegame_files"
  fi

  # Copy to Binaries folder
  mkdir -p "$server_files/StarRupture/Binaries/Win64/"
  cp "$server_files/DSSettings.txt" "$server_files/StarRupture/Binaries/Win64/DSSettings.txt"
  echo "DSSettings.txt deployed to Binaries folder."
fi

echo " "
echo "Launching StarRupture Dedicated Server"
echo " "

# Fix for SteamAPI_Init failed
# Ensure the directory exists (it might not if update was skipped and it's a fresh run)
mkdir -p "$server_files/StarRupture/Binaries/Win64/"
echo "3809400" > "$server_files/StarRupture/Binaries/Win64/steam_appid.txt"

# RUN
cd "$server_files"
EXE_PATH="$server_files/StarRupture/Binaries/Win64/StarRuptureServerEOS-Win64-Shipping.exe"

if [ ! -f "$EXE_PATH" ]; then
    echo "WARNING: Server executable not found at $EXE_PATH"
    echo "This is expected if AUTO_UPDATE was disabled on a fresh container."
fi

xvfb-run --auto-servernum wine "$EXE_PATH" -Log -port=$SERVER_PORT -QueryPort=$QUERY_PORT 2>&1