#!/bin/bash

echo " "
echo "Startup"
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

    # Retry logic for exit code 8 (often corrupt manifest)
    if [ $exit_code -eq 8 ]; then
      echo " "
      echo "SteamCMD failed with exit code 8 (often corrupt manifest)."
      echo "Attempting to fix by removing appmanifest_3809400.acf and retrying..."
      rm -f "$server_files/steamapps/appmanifest_3809400.acf"
      
      echo "Retrying update..."
      "${cmd_flags[@]}"
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
  
  if [ -d "$savegame_files" ]; then
    # Find the most recently modified session directory
    latest_session_path=$(ls -td "$savegame_files"/*/ 2>/dev/null | head -n 1)

    if [ -n "$latest_session_path" ]; then
      # Remove trailing slash if present for basename
      latest_session_path="${latest_session_path%/}"
      session_name=$(basename "$latest_session_path")
      echo "Found latest session: $session_name"
      
      # Find the latest .sav file inside this session
      latest_save_file=$(ls -t "$latest_session_path"/*.sav 2>/dev/null | head -n 1)
      
      if [ -n "$latest_save_file" ]; then
        save_name=$(basename "$latest_save_file")
        echo "Found latest save file: $save_name"
        
        # Prepare DSSettings.txt
        cp "/home/container/scripts/DSSettings.txt" "$server_files/DSSettings.txt"
        
        # Update SessionName and SaveGameName
        sed -i "s/\"SessionName\": \".*\"/\"SessionName\": \"$session_name\"/" "$server_files/DSSettings.txt"
        sed -i "s/\"SaveGameName\": \".*\"/\"SaveGameName\": \"$save_name\"/" "$server_files/DSSettings.txt"
        
        # Copy to Binaries folder as well, as the game likely looks next to the executable
        mkdir -p "$server_files/StarRupture/Binaries/Win64/"
        cp "$server_files/DSSettings.txt" "$server_files/StarRupture/Binaries/Win64/DSSettings.txt"
        
        echo "DSSettings.txt updated and placed in server root and Binaries/Win64."
      else
        echo "No .sav files found in session '$session_name'. Cannot configure resume."
      fi
    else
      echo "No savegame session folders found yet."
    fi
  else
    echo "Savegame directory does not exist yet: $savegame_files"
  fi
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