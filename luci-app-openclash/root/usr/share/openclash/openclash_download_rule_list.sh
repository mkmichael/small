#!/bin/bash
. /usr/share/openclash/log.sh
. /lib/functions.sh
. /usr/share/openclash/openclash_curl.sh

   urlencode() {
      if [ "$#" -eq 1 ]; then
         echo "$(/usr/share/openclash/openclash_urlencode.lua "$1")"
      fi
   }

   set_lock() {
      exec 870>"/tmp/lock/openclash_rulelist.lock" 2>/dev/null
      flock -x 870 2>/dev/null
   }

   del_lock() {
      flock -u 870 2>/dev/null
      rm -rf "/tmp/lock/openclash_rulelist.lock" 2>/dev/null
   }

   set_lock

   RULE_FILE_NAME="$1"
   RELEASE_BRANCH=$(uci -q get openclash.config.release_branch || echo "master")
   github_address_mod=$(uci -q get openclash.config.github_address_mod || echo 0)
   if [ -z "$(grep "$RULE_FILE_NAME" /usr/share/openclash/res/rule_providers.list 2>/dev/null)" ]; then
      DOWNLOAD_PATH=$(grep -F "$RULE_FILE_NAME" /usr/share/openclash/res/game_rules.list |awk -F ',' '{print $2}' 2>/dev/null)
      RULE_FILE_DIR="/etc/openclash/game_rules/$RULE_FILE_NAME"
      RULE_TYPE="game"
   else
      DOWNLOAD_PATH=$(echo "$RULE_FILE_NAME" |awk -F ',' '{print $1$2}' 2>/dev/null)
      RULE_FILE_NAME=$(grep -F "$RULE_FILE_NAME" /usr/share/openclash/res/rule_providers.list |awk -F ',' '{print $NF}' 2>/dev/null)
      RULE_FILE_DIR="/etc/openclash/rule_provider/$RULE_FILE_NAME"
      RULE_TYPE="provider"
   fi

   if [ -z "$DOWNLOAD_PATH" ]; then
      LOG_OUT "Rule File【$RULE_FILE_NAME】Download Error!" && SLOG_CLEAN
      del_lock
      exit 0
   fi

   TMP_RULE_DIR="/tmp/$RULE_FILE_NAME"
   TMP_RULE_DIR_TMP="/tmp/$RULE_FILE_NAME.tmp"
   DOWNLOAD_PATH=$(urlencode "$DOWNLOAD_PATH")
   
   if [ "$RULE_TYPE" = "game" ]; then
      if [ "$github_address_mod" != "0" ]; then
         if [ "$github_address_mod" == "https://cdn.jsdelivr.net/" ] || [ "$github_address_mod" == "https://fastly.jsdelivr.net/" ] || [ "$github_address_mod" == "https://testingcf.jsdelivr.net/" ]; then
            DOWNLOAD_URL="${github_address_mod}gh/FQrabbit/SSTap-Rule@master/rules/${DOWNLOAD_PATH}"
         else
            DOWNLOAD_URL="${github_address_mod}https://raw.githubusercontent.com/FQrabbit/SSTap-Rule/master/rules/${DOWNLOAD_PATH}"
         fi
      else
         DOWNLOAD_URL="https://raw.githubusercontent.com/FQrabbit/SSTap-Rule/master/rules/${DOWNLOAD_PATH}"
      fi
   elif [ "$RULE_TYPE" = "provider" ]; then
      if [ "$github_address_mod" != "0" ]; then
         if [ "$github_address_mod" == "https://cdn.jsdelivr.net/" ] || [ "$github_address_mod" == "https://fastly.jsdelivr.net/" ] || [ "$github_address_mod" == "https://testingcf.jsdelivr.net/" ]; then
            DOWNLOAD_URL="${github_address_modgh}/$(echo ${DOWNLOAD_PATH} |awk -F '/master' '{print $1}' 2>/dev/null)@master$(echo ${DOWNLOAD_PATH} |awk -F 'master' '{print $2}')"
         else
            DOWNLOAD_URL="${github_address_mod}https://raw.githubusercontent.com/${DOWNLOAD_PATH}"
         fi
      else
         DOWNLOAD_URL="https://raw.githubusercontent.com/${DOWNLOAD_PATH}"
      fi
   fi

   DOWNLOAD_FILE_CURL "$DOWNLOAD_URL" "$TMP_RULE_DIR"

   if [ "$?" -eq 0 ] && [ -s "$TMP_RULE_DIR" ]; then
      if [ "$RULE_TYPE" = "game" ]; then
      	cat "$TMP_RULE_DIR" |sed '/^#/d' 2>/dev/null |sed '/^ *$/d' 2>/dev/null |awk '{print "  - "$0}' > "$TMP_RULE_DIR_TMP" 2>/dev/null
      	sed -i '1i\payload:' "$TMP_RULE_DIR_TMP" 2>/dev/null
      	cmp -s "$TMP_RULE_DIR_TMP" "$RULE_FILE_DIR"
      else
         cmp -s "$TMP_RULE_DIR" "$RULE_FILE_DIR"
      fi
         if [ "$?" -ne "0" ]; then
            if [ "$RULE_TYPE" = "game" ]; then
               mv "$TMP_RULE_DIR_TMP" "$RULE_FILE_DIR" >/dev/null 2>&1
            else
               mv "$TMP_RULE_DIR" "$RULE_FILE_DIR" >/dev/null 2>&1
            fi
            rm -rf "$TMP_RULE_DIR" >/dev/null 2>&1
            LOG_OUT "Rule File【$RULE_FILE_NAME】Download Successful!" && SLOG_CLEAN
            del_lock
            exit 1
         else
            LOG_OUT "Rule File【$RULE_FILE_NAME】No Change, Do Nothing!" && SLOG_CLEAN
            rm -rf "$TMP_RULE_DIR" >/dev/null 2>&1
            rm -rf "$TMP_RULE_DIR_TMP" >/dev/null 2>&1
            del_lock
            exit 2
         fi
   else
      rm -rf "$TMP_RULE_DIR" >/dev/null 2>&1
      LOG_OUT "Rule File【$RULE_FILE_NAME】Download Error!" && SLOG_CLEAN
      del_lock
      exit 0
   fi

   del_lock
