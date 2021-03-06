#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

setup_prechecks()
{
    log "Setup Pre-check"
    debug "SETUP_COMPLETED='${config[SETUP_COMPLETED]}'"
    debug "CHANGE_PASS='${config[CHANGE_PASS]}'"
    debug "OPENFLIXR_PASSWORD_NEW='${OPENFLIXR_PASSWORD_NEW}'"
    if [[ ${config[SETUP_COMPLETED]} != "Y" && ${config[CHANGE_PASS]} == "Y" && ${OPENFLIXR_PASSWORD_NEW} == "" ]]; then
        log "Setup Pre-check: Asking if the user still wants to change the password"
        if run_script 'question_prompt' Y $"It has been detected that you wanted to change the password for OpenFLIXR.\nThe setup doesn't store your new password so you will need to re-enter it.\nDo you still want to change the password?" "Confirm password change"; then
            log "Setup Pre-check: Still changing password"
            run_script 'step_change_password' "Change Password Check" "N"
        else
            log "Setup Pre-check: No longer wants to change the password"
            set_config "CHANGE_PASS" "N"
        fi
    elif [[ ${config[SETUP_COMPLETED]} == "Y" && ${config[CHANGE_PASS]} == "Y" && ${OPENFLIXR_PASSWORD_NEW} == "" ]]; then
        log "Setup Pre-check: Setup completed, CHANGE_PASS is 'Y', and no new password provided."
        #set_config "CHANGE_PASS" "N"
    fi
}
