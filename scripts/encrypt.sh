#!/usr/bin/bash
# -*- coding: utf-8 -*-
# region header
# [Project page](https://torben.website/containerbase)

# Copyright Torben Sickert (info["~at~"]torben.website) 16.12.2012

# License
# -------

# This library written by Torben Sickert stand under a creative commons naming
# 3.0 unported license.
# See https://creativecommons.org/licenses/by/3.0/deed.de
# endregion
# shellcheck disable=SC2016,SC2034,SC2155
# region convert environment variables given as string into local arrays
for name in \
    DECRYPTED_PATHS \
    ENCRYPTED_PATHS \
    ENVIRONMENT_FILE_PATHS \
    PASSWORD_FILE_PATHS
do
    if ! [[ "$(declare -p "$name" 2>/dev/null)" =~ 'declare -a' ]]; then
        eval "declare -a ${name}_ARRAY=(\$${name})"
    fi
done
# endregion
# region load dynamic environment variables
for file_path in "${ENVIRONMENT_FILE_PATHS_ARRAY[@]}"; do
    if [ -f "$file_path" ]; then
        # shellcheck disable=SC1090
        source "$file_path"
    fi
done
# endregion
# region determine encrypter
for encrypter in \
    /tmp/gpgdir \
    /usr/bin/gpgdir \
    /usr/bin/perlbin/site_perl/gpgdir \
    /tmp/gpgdir-nodeps-*/gpgdir
do
    if [ -f "$encrypter" ]; then
        break
    fi
done
run() {
    if (( HOST_USER_ID == 0 )) || [ "$USER" = "$MAIN_USER_NAME" ]; then
        "$@"
    else
        su "$MAIN_USER_NAME" --group "$MAIN_USER_GROUP_NAME" -c "$*"
    fi
}
encrypt() {
    local password_file_parameters=()
    if [[ "$2" != '' ]]; then
        password_file_parameters=('--pw-file' "$2")
    fi

    run "$encrypter" \
        --encrypt "$1" \
        --overwrite-encrypted \
        --Symmetric \
        --verbose \
        "${password_file_parameters[@]}"

    return $?
}
# endregion
# region encrypt security related artefacts needed at runtime
for index in "${!ENCRYPTED_PATHS_ARRAY[@]}"; do
    if [ -d "${DECRYPTED_PATHS_ARRAY[index]}" ]; then
        rm \
            --force \
            --recursive \
            "${ENCRYPTED_PATHS_ARRAY[index]}" \
                &>/dev/null
        mkdir --parents "${ENCRYPTED_PATHS_ARRAY[index]}"
        chown \
            --recursive \
            "$MAIN_USER_NAME:$MAIN_USER_GROUP_NAME" \
            "${ENCRYPTED_PATHS_ARRAY[index]}"

        declare password_file_path=/tmp/intermediatePasswordFile

        run cp \
            --force \
            --preserve=all \
            --recursive \
            "${DECRYPTED_PATHS_ARRAY[index]}"/* \
            "${ENCRYPTED_PATHS_ARRAY[index]}"

        if [ -s "/run/secrets/${PASSWORD_SECRET_NAMES[index]}" ]; then
            password_file_path="/run/secrets/${PASSWORD_SECRET_NAMES[index]}"
        elif [ -s "${PASSWORD_FILE_PATHS_ARRAY[index]}" ]; then
            password_file_path="${PASSWORD_FILE_PATHS_ARRAY[index]}"
        elif [[ "$DECRYPTION_PASSWORD" != '' ]]; then
            run echo -n "$DECRYPTION_PASSWORD" >"$password_file_path"
        elif [[ "$1" != '' ]]; then
            run echo -n "$1" >"$password_file_path"
        fi

        if [ -s "$password_file_path" ]; then
            if ! encrypt \
                "${ENCRYPTED_PATHS_ARRAY[index]}" \
                "$password_file_path"
            then
                echo \
                    "Encrypting \"${DECRYPTED_PATHS_ARRAY[index]}\" to" \
                    "\"${ENCRYPTED_PATHS_ARRAY[index]}\" failed."

                exit 1
            fi
        elif ! encrypt "${ENCRYPTED_PATHS_ARRAY[index]}"; then
            echo \
                "Encrypting \"${DECRYPTED_PATHS_ARRAY[index]}\" to" \
                "\"${ENCRYPTED_PATHS_ARRAY[index]}\" failed."

            exit 1
        fi

        echo \
            "Encrypting \"${DECRYPTED_PATHS_ARRAY[index]}\" to" \
            "\"${ENCRYPTED_PATHS_ARRAY[index]}\" successfully finished."
    fi
done
# endregion
# region vim modline
# vim: set tabstop=4 shiftwidth=4 expandtab:
# vim: foldmethod=marker foldmarker=region,endregion:
# endregion
