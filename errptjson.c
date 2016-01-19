/*
 * Copyright © 2016 Absolute Performance Inc <csteam@absolute-performance.com>.
 * Written by Taylor C. Richberger <tcr@absolute-performance.com>
 * All rights reserved.
 * This is proprietary software.
 * No warranty, explicit or implicit, provided.
 */

// This can be compiled with gcc -oerrptjson errptjson.c -ljson-c -lerrlog -std=c99
// You may want to compile to an object and mung with the linker to get json-c to statically link

#include <fcntl.h>
#include <stdio.h>
#include <sys/errlog.h>

#include <json-c/json.h>

int main(int argc, char **argv)
{
    json_object *errptlist = json_object_new_array();

    errlog_handle_t handle;
    const int mode = O_RDONLY;

    const int magic = LE_MAGIC;

    /* path of error log file */
    char path[]="/var/adm/ras/errlog";

    errlog_entry_t entry;

    /* opening error log file */
    int rc = errlog_open(path, mode, magic, &handle);

    if (rc)
    {
        fprintf(stderr, "Failed to open error log file %s, error: %d\n", path, rc);
    }

    errlog_match_t match;
    match.em_op = LE_OP_GT;
    match.emu1.emu_field = LE_MATCH_SEQUENCE;

    if (argc > 1)
    {
        match.emu2.emu_intvalue = atol(argv[1]);
    } else
    {
        match.emu2.emu_intvalue = 0;
    }

    for (rc = errlog_find_first(handle, &match, &entry); !rc; rc = errlog_find_next(handle, &entry))
    {
        json_object *entobj = json_object_new_object();
        json_object_array_add(errptlist, entobj);

        json_object_object_add(entobj, "magic", json_object_new_int64(entry.el_magic));
        json_object_object_add(entobj, "sequence", json_object_new_int64(entry.el_sequence));
        json_object_object_add(entobj, "label", json_object_new_string(entry.el_label));
        json_object_object_add(entobj, "timestamp", json_object_new_int64(entry.el_timestamp));
        json_object_object_add(entobj, "crcid", json_object_new_int64(entry.el_crcid));
        json_object_object_add(entobj, "errdiag", json_object_new_int64(entry.el_errdiag));
        json_object_object_add(entobj, "machineid", json_object_new_string(entry.el_machineid));
        json_object_object_add(entobj, "nodeid", json_object_new_string(entry.el_nodeid));
        json_object_object_add(entobj, "class", json_object_new_string(entry.el_class));
        json_object_object_add(entobj, "type", json_object_new_string(entry.el_type));
        json_object_object_add(entobj, "resource", json_object_new_string(entry.el_resource));
        json_object_object_add(entobj, "rclass", json_object_new_string(entry.el_rclass));
        json_object_object_add(entobj, "rtype", json_object_new_string(entry.el_rtype));
        json_object_object_add(entobj, "vpd_ibm", json_object_new_string(entry.el_vpd_ibm));
        json_object_object_add(entobj, "vpd_user", json_object_new_string(entry.el_vpd_user));
        json_object_object_add(entobj, "in", json_object_new_string(entry.el_in));
        json_object_object_add(entobj, "connwhere", json_object_new_string(entry.el_connwhere));

        json_object *flagsobj = json_object_new_object();
        json_object_object_add(flagsobj, "64", json_object_new_boolean(entry.el_flags & LE_FLAG_ERR64));
        json_object_object_add(flagsobj, "dup", json_object_new_boolean(entry.el_flags & LE_FLAG_ERRDUP));
        json_object_object_add(flagsobj, "wpar", json_object_new_boolean(entry.el_flags & LE_FLAG_ERRWPAR));
        json_object_object_add(entobj, "flags", flagsobj);

        json_object_object_add(entobj, "detail_data", json_object_new_string_len(entry.el_detail_data, entry.el_detail_length));
        json_object_object_add(entobj, "symptom_data", json_object_new_string_len(entry.el_symptom_data, entry.el_symptom_length));

        json_object *errdupobj = json_object_new_object();
        json_object_object_add(errdupobj, "dupcount", json_object_new_int64(entry.el_errdup.ed_dupcount));
        json_object_object_add(errdupobj, "time1", json_object_new_int64(entry.el_errdup.ed_time1));
        json_object_object_add(errdupobj, "time2", json_object_new_int64(entry.el_errdup.ed_time2));
        json_object_object_add(entobj, "flags", errdupobj);

        json_object_object_add(entobj, "wparid", json_object_new_string(entry.el_wparid));
    }

    if (rc != LE_ERR_DONE)
    {
        fprintf(stderr, "Error while processing errpt entries: %d\n", rc);
    }
    puts(json_object_to_json_string(errptlist));
    /* Free errptlist */
    json_object_put(errptlist);

    errlog_close(handle);
    return 0;
}
