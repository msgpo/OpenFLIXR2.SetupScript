#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

setup_configure_movie_manager()
{
    local ENABLED_HTPC
    local ENABLED_OMBI

    info "Configuring Movies Manager"
    info "- Couchpotato"
    info "  Updating API Key"
    crudini --set /opt/CouchPotato/settings.conf core api_key ${API_KEYS[couchpotato]}
    crudini --set /opt/CouchPotato/settings.conf sabnzbd api_key ${API_KEYS[sabnzbd]}

    # TODO: Revisit
    # if [ "$imdb" != '' ]; then
    #     info "  Connecting to IMDB"
    #     crudini --set /opt/CouchPotato/settings.conf imdb automation_urls $imdb
    #     crudini --set /opt/CouchPotato/settings.conf imdb automation_urls_use 1
    # else
    #     crudini --set /opt/CouchPotato/settings.conf imdb automation_urls
    #     crudini --set /opt/CouchPotato/settings.conf imdb automation_urls_use 0
    # fi

    info "- Radarr"
    info "  Updating API Key"
    sed -i 's/^  <ApiKey>.*/  <ApiKey>'${API_KEYS[radarr]}'<\/ApiKey>/' /root/.config/Radarr/config.xml
    info "  Updating Radarr settings"

    if [[ -f "/root/.config/Radarr/nzbdrone.db" ]]; then
        info "  - Updating Indexer settings"
        info "    NZBHydra"
        local radarr_nzbhydra_check
        radarr_nzbhydra_check=$(sqlite3 /root/.config/Radarr/nzbdrone.db "SELECT COUNT(id) FROM Indexers WHERE Name='NZBHydra'")
        if [[ $radarr_nzbhydra_check == 0 ]]; then
            warning "NZBHydra not found in the database... Attempting to add it."
            sqlite3 /root/.config/Radarr/nzbdrone.db "
                INSERT INTO Indexers
                (Name,
                Implementation,
                Settings,
                ConfigContract,
                EnableRss,
                EnableSearch)
                VALUES ('NZBHydra',
                        'Newznab',
                        '{
                            \"baseUrl\": \"http://localhost:5075/nzbhydra\",
                            \"multiLanguages\": [],
                            \"apiKey\": \"fakekey\",
                            \"categories\": [
                                2000,
                                2010,
                                2020,
                                2030,
                                2035,
                                2040,
                                2045,
                                2050,
                                2060
                            ],
                            \"animeCategories\": [],
                            \"removeYear\": false,
                            \"searchByTitle\": false
                        }',
                        'NewznabSettings',
                        1,
                        1);
                "
        fi
        local radarr_nzbhydra_id
        radarr_nzbhydra_id=$(sqlite3 /root/.config/Radarr/nzbdrone.db "SELECT id FROM Indexers WHERE Name='NZBHydra'")
        local radarr_nzbhydra_settings
        radarr_nzbhydra_settings=$(sqlite3 /root/.config/Radarr/nzbdrone.db "SELECT Settings FROM Indexers WHERE id=$radarr_nzbhydra_id")
        # Set NZBHydra API Key
        debug "Setting API Key to: ${API_KEYS[nzbhydra2]}"
        radarr_nzbhydra_settings=$(sed 's/"apiKey":.*/"apiKey": "'${API_KEYS[nzbhydra2]}'",/' <<< $radarr_nzbhydra_settings)
        # Set NZBHydra baseUrl
        debug "Setting Base URL to: http://localhost:5075/nzbhydra"
        radarr_nzbhydra_settings=$(sed 's#"baseUrl":.*#"baseUrl": "http://localhost:5075/nzbhydra",#' <<< $radarr_nzbhydra_settings)
        debug "Updating DB"
        sqlite3 /root/.config/Radarr/nzbdrone.db "UPDATE Indexers SET Settings='$radarr_nzbhydra_settings' WHERE id=$radarr_nzbhydra_id"

        info "  - Updating Downloader settings"
        info "    NZBget"
        local radarr_nzbget_check
        radarr_nzbget_check=$(sqlite3 /root/.config/Radarr/nzbdrone.db "SELECT COUNT(id) FROM DownloadClients WHERE Name='NZBget'")
        if [[ $radarr_nzbget_check == 0 ]]; then
            warning "NZBget not found in the database... Attempting to add it."
            sqlite3 /root/.config/Radarr/nzbdrone.db "
                INSERT INTO DownloadClients
                (Enable,
                Name,
                Implementation,
                Settings,
                ConfigContract)
                VALUES (1,
                        'NZBget',
                        'Nzbget',
                        '{
                            \"host\": \"localhost\",
                            \"port\": 6789,
                            \"username\": \"\",
                            \"password\": \"\",
                            \"tvCategory\": \"movies\",
                            \"recentTvPriority\": 0,
                            \"olderTvPriority\": 0,
                            \"useSsl\": false,
                            \"addPaused\": false
                        }',
                        'NzbgetSettings'
                        );
                "
        fi
        local radarr_nzbget_id
        radarr_nzbget_id=$(sqlite3 /root/.config/Radarr/nzbdrone.db "SELECT id FROM DownloadClients WHERE Name='NZBget'")
        local radarr_nzbget_settings
        radarr_nzbget_settings=$(sqlite3 /root/.config/Radarr/nzbdrone.db "SELECT Settings FROM DownloadClients WHERE id=$radarr_nzbget_id")
        # Change movieCategory to lowercase
        debug "Setting movieCategory to: movies"
        radarr_nzbget_settings=$(sed 's/"movieCategory":.*/"movieCategory": "movies",/' <<< $radarr_nzbget_settings)
        debug "Updating DB"
        if [[ ${config[NZB_DOWNLOADER]} == 'nzbget' ]]; then
            sqlite3 /root/.config/Radarr/nzbdrone.db "UPDATE DownloadClients SET Enable=1 WHERE id=$radarr_nzbget_id"
        else
            sqlite3 /root/.config/Radarr/nzbdrone.db "UPDATE DownloadClients SET Enable=0 WHERE id=$radarr_nzbget_id"
        fi
        sqlite3 /root/.config/Radarr/nzbdrone.db "UPDATE DownloadClients SET Settings='$radarr_nzbget_settings' WHERE id=$radarr_nzbget_id"

        info "    SABnzb"
        local radarr_sabnzb_check
        radarr_sabnzb_check=$(sqlite3 /root/.config/Radarr/nzbdrone.db "SELECT COUNT(id) FROM DownloadClients WHERE Name='SABnzbd'")
        if [[ $radarr_sabnzb_check == 0 ]]; then
            warning "SABnzbd not found in the database... Attempting to add it."
            sqlite3 /root/.config/Radarr/nzbdrone.db "
                INSERT INTO DownloadClients
                (Enable,
                Name,
                Implementation,
                Settings,
                ConfigContract)
                VALUES (1,
                        'SABnzbd',
                        'SABnzbd',
                        '{
                            \"host\": \"localhost\",
                            \"port\": 8080,
                            \"apiKey\": \"fakekey\",
                            \"tvCategory\": \"movies\",
                            \"recentTvPriority\": -100,
                            \"olderTvPriority\": -100,
                            \"useSsl\": false
                        }',
                        'SabnzbdSettings'
                        );
                "
        fi
        local radarr_sabnzb_id
        radarr_sabnzb_id=$(sqlite3 /root/.config/Radarr/nzbdrone.db "SELECT id FROM DownloadClients WHERE Name='SABnzbd'")
        local radarr_sabnzb_settings
        radarr_sabnzb_settings=$(sqlite3 /root/.config/Radarr/nzbdrone.db "SELECT Settings FROM DownloadClients WHERE id=$radarr_sabnzb_id")
        # Set SABnzb API Key
        debug "Setting API Key to: ${API_KEYS[sabnzbd]}"
        radarr_sabnzb_settings=$(sed 's/"apiKey":.*/"apiKey": "'${API_KEYS[sabnzbd]}'",/' <<< $radarr_sabnzb_settings)
        debug "Updating DB"
        if [[ ${config[NZB_DOWNLOADER]} == 'sabnzbd' ]]; then
            sqlite3 /root/.config/Radarr/nzbdrone.db "UPDATE DownloadClients SET Enable=1 WHERE id=$radarr_sabnzb_id"
        else
            sqlite3 /root/.config/Radarr/nzbdrone.db "UPDATE DownloadClients SET Enable=0 WHERE id=$radarr_sabnzb_id"
        fi
        sqlite3 /root/.config/Radarr/nzbdrone.db "UPDATE DownloadClients SET Settings='$radarr_sabnzb_settings' WHERE id=$radarr_sabnzb_id"
    else
        warning "Unable to find '/root/.config/Radarr/nzbdrone.db'. Can't update any other Radarr settings"
    fi
}
