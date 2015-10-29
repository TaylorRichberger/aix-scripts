/*
 * Copyright © 2015 Absolute Performance Inc <csteam@absolute-performance.com>.
 * Written by Taylor C. Richberger <tcr@absolute-performance.com>
 * All rights reserved.
 * This is proprietary software.
 * No warranty, explicit or implicit, provided.
 */

// This can be compiled with gcc -opsjson psjson.c -ljson-c
// You may want to compile to an object and mung with the linker to get json-c to statically link

// This was initially to be a Perl utility for json procfs reading, to not have
// to screw with the ps output (which is horridly unreliable and changes based
// on terminal width, as well as having a changing and virtually unparsable
// start timestamp), but Perl could not read 64-bit integers from the structure
// with Unpack, and to attempt to pull out the data manually (in two 32-bit
// chunks) looked like it was going to make it unreliable to match a ppid to a
// pid, which was part of the main point of this.
//
// After that, we were going to use a Perl XSUB to do it, but the XSUB,
// compiled with GCC, did not want to play nice with the Perl implementation,
// compiled with XL C++.  It seemed easier to just write a C program to read it
// and serialize it for regular consumption.  Perl's JSON module appears to
// serialize large integers to strings, which works fine for matching purposes.

#include <sys/procfs.h>
#include <sys/types.h>
#include <fcntl.h>
#include <dirent.h>
#include <unistd.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <ctype.h>
#include <inttypes.h>

#include <json-c/json.h>

static int isnumberstring(const char *s);

int main()
{
    json_object *proclist = json_object_new_array();

    DIR *dir = opendir("/proc");

    struct dirent *ent = readdir(dir);
    while (ent)
    {
        if (isnumberstring(ent->d_name))
        {
            size_t pathsize = sizeof("/proc/") + sizeof("/psinfo") + strlen(ent->d_name);
            char filepath[pathsize];
            *filepath = '\0';
            strcat(strcat(strcpy(filepath, "/proc/"), ent->d_name), "/psinfo");
            FILE *file = fopen(filepath, "rb");
            if (file)
            {
                struct psinfo info;
                fread(&info.pr_flag, sizeof(info.pr_flag), 1, file);
                fread(&info.pr_flag2, sizeof(info.pr_flag2), 1, file);
                fread(&info.pr_nlwp, sizeof(info.pr_nlwp), 1, file);
                fread(&info.pr__pad1, sizeof(info.pr__pad1), 1, file);
                fread(&info.pr_uid, sizeof(info.pr_uid), 1, file);
                fread(&info.pr_euid, sizeof(info.pr_euid), 1, file);
                fread(&info.pr_gid, sizeof(info.pr_gid), 1, file);
                fread(&info.pr_egid, sizeof(info.pr_egid), 1, file);
                fread(&info.pr_pid, sizeof(info.pr_pid), 1, file);
                fread(&info.pr_ppid, sizeof(info.pr_ppid), 1, file);
                fread(&info.pr_pgid, sizeof(info.pr_pgid), 1, file);
                fread(&info.pr_sid, sizeof(info.pr_sid), 1, file);
                fread(&info.pr_ttydev, sizeof(info.pr_ttydev), 1, file);
                fread(&info.pr_addr, sizeof(info.pr_addr), 1, file);
                fread(&info.pr_size, sizeof(info.pr_size), 1, file);
                fread(&info.pr_rssize, sizeof(info.pr_rssize), 1, file);
                fread(&info.pr_start.tv_sec, sizeof(info.pr_start.tv_sec), 1, file);
                fread(&info.pr_start.tv_nsec, sizeof(info.pr_start.tv_nsec), 1, file);
                fread(&info.pr_start.__pad, sizeof(info.pr_start.__pad), 1, file);
                fread(&info.pr_time.tv_sec, sizeof(info.pr_time.tv_sec), 1, file);
                fread(&info.pr_time.tv_nsec, sizeof(info.pr_time.tv_nsec), 1, file);
                fread(&info.pr_time.__pad, sizeof(info.pr_time.__pad), 1, file);
                fread(&info.pr_cid, sizeof(info.pr_cid), 1, file);
                fread(&info.pr__pad2, sizeof(info.pr__pad2), 1, file);
                fread(&info.pr_argc, sizeof(info.pr_argc), 1, file);
                fread(&info.pr_argv, sizeof(info.pr_argv), 1, file);
                fread(&info.pr_envp, sizeof(info.pr_envp), 1, file);
                fread(info.pr_fname, sizeof(info.pr_fname), 1, file);
                fread(info.pr_psargs, sizeof(info.pr_psargs), 1, file);
                fread(info.pr__pad, sizeof(info.pr__pad), 1, file);
                fread(&info.pr_lwp.pr_lwpid, sizeof(info.pr_lwp.pr_lwpid), 1, file);
                fread(&info.pr_lwp.pr_addr, sizeof(info.pr_lwp.pr_addr), 1, file);
                fread(&info.pr_lwp.pr_wchan, sizeof(info.pr_lwp.pr_wchan), 1, file);
                fread(&info.pr_lwp.pr_flag, sizeof(info.pr_lwp.pr_flag), 1, file);
                fread(&info.pr_lwp.pr_wtype, sizeof(info.pr_lwp.pr_wtype), 1, file);
                fread(&info.pr_lwp.pr_state, sizeof(info.pr_lwp.pr_state), 1, file);
                fread(&info.pr_lwp.pr_sname, sizeof(info.pr_lwp.pr_sname), 1, file);
                fread(&info.pr_lwp.pr_nice, sizeof(info.pr_lwp.pr_nice), 1, file);
                fread(&info.pr_lwp.pr_pri, sizeof(info.pr_lwp.pr_pri), 1, file);
                fread(&info.pr_lwp.pr_policy, sizeof(info.pr_lwp.pr_policy), 1, file);
                fread(info.pr_lwp.pr_clname, sizeof(info.pr_lwp.pr_clname), 1, file);
                fread(&info.pr_lwp.pr_onpro, sizeof(info.pr_lwp.pr_onpro), 1, file);
                fread(&info.pr_lwp.pr_bindpro, sizeof(info.pr_lwp.pr_bindpro), 1, file);
                fread(&info.pr_lwp.pr_ptid, sizeof(info.pr_lwp.pr_ptid), 1, file);
                fread(&info.pr_lwp.pr__pad1, sizeof(info.pr_lwp.pr__pad1), 1, file);
                fread(info.pr_lwp.pr__pad, sizeof(info.pr_lwp.pr__pad), 1, file);

                json_object *psobj = json_object_new_object();
                json_object *lwpobj = json_object_new_object();

                json_object_object_add(psobj, "lwp", lwpobj);
                json_object_array_add(proclist, psobj);

                json_object_object_add(psobj, "flag", json_object_new_int(info.pr_flag));
                json_object_object_add(psobj, "flag2", json_object_new_int(info.pr_flag2));
                json_object_object_add(psobj, "nlwp", json_object_new_int(info.pr_nlwp));
                json_object_object_add(psobj, "uid", json_object_new_int64(info.pr_uid));
                json_object_object_add(psobj, "euid", json_object_new_int64(info.pr_euid));
                json_object_object_add(psobj, "gid", json_object_new_int64(info.pr_gid));
                json_object_object_add(psobj, "egid", json_object_new_int64(info.pr_egid));
                json_object_object_add(psobj, "pid", json_object_new_int64(info.pr_pid));
                json_object_object_add(psobj, "ppid", json_object_new_int64(info.pr_ppid));
                json_object_object_add(psobj, "pgid", json_object_new_int64(info.pr_pgid));
                json_object_object_add(psobj, "sid", json_object_new_int64(info.pr_sid));
                json_object_object_add(psobj, "ttydev", json_object_new_int64(info.pr_ttydev));
                json_object_object_add(psobj, "addr", json_object_new_int64(info.pr_addr));
                json_object_object_add(psobj, "size", json_object_new_int64(info.pr_size));
                json_object_object_add(psobj, "rssize", json_object_new_int64(info.pr_rssize));
                json_object_object_add(psobj, "start", json_object_new_int64(info.pr_start.tv_sec));
                json_object_object_add(psobj, "time", json_object_new_int64(info.pr_time.tv_sec));
                json_object_object_add(psobj, "cid", json_object_new_int(info.pr_cid));
                json_object_object_add(psobj, "argc", json_object_new_int(info.pr_argc));
                json_object_object_add(psobj, "argv", json_object_new_int64(info.pr_argv));
                json_object_object_add(psobj, "envp", json_object_new_int64(info.pr_envp));
                json_object_object_add(psobj, "fname", json_object_new_string(info.pr_fname));
                json_object_object_add(psobj, "psargs", json_object_new_string(info.pr_psargs));

                json_object_object_add(lwpobj, "lwpid", json_object_new_int64(info.pr_lwp.pr_lwpid));
                json_object_object_add(lwpobj, "addr", json_object_new_int64(info.pr_lwp.pr_addr));
                json_object_object_add(lwpobj, "wchan", json_object_new_int64(info.pr_lwp.pr_wchan));
                json_object_object_add(lwpobj, "flag", json_object_new_int(info.pr_lwp.pr_flag));
                json_object_object_add(lwpobj, "wtype", json_object_new_int(info.pr_lwp.pr_wtype));
                json_object_object_add(lwpobj, "state", json_object_new_int(info.pr_lwp.pr_state));
                json_object_object_add(lwpobj, "sname", json_object_new_string_len(&info.pr_lwp.pr_sname, 1)); // Single character
                json_object_object_add(lwpobj, "nice", json_object_new_int(info.pr_lwp.pr_nice));
                json_object_object_add(lwpobj, "pri", json_object_new_int(info.pr_lwp.pr_pri));
                json_object_object_add(lwpobj, "policy", json_object_new_int(info.pr_lwp.pr_policy));
                json_object_object_add(lwpobj, "clname", json_object_new_string(info.pr_lwp.pr_clname));
                json_object_object_add(lwpobj, "onpro", json_object_new_int(info.pr_lwp.pr_onpro));
                json_object_object_add(lwpobj, "bindpro", json_object_new_int(info.pr_lwp.pr_bindpro));
                json_object_object_add(lwpobj, "ptid", json_object_new_int(info.pr_lwp.pr_ptid));
                fclose(file);
            }
        }
        ent = readdir(dir);
    }
    closedir(dir);
    puts(json_object_to_json_string(proclist));
    // Free proclist
    json_object_put(proclist);
    return 0;
}

// Returns true if the string has a length greater than 0 and its characters are all digits
static int isnumberstring(const char *s)
{       
    char nonzero = 0;
    while (*s)
    {       
        nonzero = 1;
        if (!isdigit(*s++))
        {       
            return 0;
        }
    }
    return nonzero;
}
