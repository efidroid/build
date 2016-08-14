/*
 * Copyright 2016, The EFIDroid Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
*/

#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <limits.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

int getpidproc(void) {
    int pid;

    FILE* f = fopen("/proc/self/stat","r");
    if(!f) {
        fprintf(stderr, "can't open /proc/self/stat: %s\n", strerror(errno));
        return -1;
    }

    if(fscanf(f, "%d", &pid)!=1) {
        pid = -1;
        goto out;
    }

out:
    fclose(f);

    return pid;
}


int getppidex(int pid) {
    int _pid;
    char buf[256];
    char state;
    int ppid;

    sprintf(buf, "/proc/%d/stat", pid);
    FILE* f = fopen(buf,"r");
    if(!f) {
        fprintf(stderr, "can't open %s: %s\n", buf, strerror(errno));
        return -1;
    }

    if(fscanf(f, "%d %s %c %d", &_pid, buf, &state, &ppid)!=4) {
        ppid = -1;
        goto out;
    }

out:
    fclose(f);

    return ppid;
}

ssize_t getenvvar(char **lineptr, size_t *n, FILE *stream) {
    if(*lineptr==NULL) {
        *n = 100;
        *lineptr = malloc(*n);
    }
    
    size_t num = 0;
    int c;
    while((c=fgetc(stream))!=EOF) {
        if(num+1>*n) {
            *lineptr = realloc(*lineptr, ++(*n));
            if(!(*lineptr)) break;
        }

        (*lineptr)[num++] = (char)c;
        if(c==0) break;
    }

    if(c==EOF && c && num)
        (*lineptr)[num++] = 0;

    return num;
}

int has_makeflags(int pid) {
    int rc = 0;
    char buf[1024];
    sprintf(buf, "/proc/%d/environ", pid);
    FILE* f = fopen(buf,"r");
    if(!f) {
        fprintf(stderr, "can't open %s: %s\n", buf, strerror(errno));
        return -1;
    }

    char *nameval = NULL;
    size_t size = 0;
    const char* needle = "MAKEFLAGS=";
    while(getenvvar(&nameval, &size, f)>0) {
        if(!strncmp(nameval, needle, strlen(needle))) {
            rc = 1;
            break;
        }
    }

    if(nameval)
        free(nameval);

    fclose(f);
    return rc;
}

int main(int argc, char** argv) {
    char buf[PATH_MAX];

    // check arguments
    if(argc<=1) {
        fprintf(stderr, "No arguments given!\n");
        exit(-1);
    }

    // check if any of our parents is 'make'
    int pid = getpidproc();
    if(has_makeflags(pid)!=1) {
        fprintf(stderr, "Not running in a make context!\n");
        exit(-1);
    }

    // get first parent without MAKEFLAGS
    int found = 0;
    while((pid=getppidex(pid))>=0) {
        if(has_makeflags(pid)!=1) {
            found = 1;
            break;
        }
    }

    if(found==0) {
        fprintf(stderr, "make not found!\n");
        exit(-1);
    }

    // connect jobserver pipes
    snprintf(buf, sizeof(buf), "/proc/%d/fd/%d", pid, 3);
    open(buf, O_RDONLY);    
    snprintf(buf, sizeof(buf), "/proc/%d/fd/%d", pid, 4);
    open(buf, O_WRONLY);

    // run requested binary
    int rc = execvp(argv[1], argv+1);

    fprintf(stderr, "execve returned! %d\n", rc);
    return -1;
}
