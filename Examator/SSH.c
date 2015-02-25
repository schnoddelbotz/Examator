//
//  SSH.c
//  Examator
//
//  Created by jan on 21/02/15.
//  Copyright (c) 2015 schnoddelbotz. All rights reserved.
//
// heavily based on
//  libssh_scp.c - Sample implementation of a SCP client
//  Copyright 2009 Aris Adamantiadis
// and other libssh example code

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <sys/stat.h>
#include <math.h>

#include "libssh.h"
#include "callbacks.h"
#include "sftp.h"
#include "ssh2.h"

#include "Examator-Bridging-Header.h"
ssh_session connect_ssh(const char *hostname, const char *user, int verbosity);

static int verbosity=0;

struct location {
  int is_ssh;
  char *user;
  char *host;
  char *path;
  ssh_session session;
  ssh_scp scp;
  FILE *file;
};

enum {
  READ,
  WRITE
};

void initLibSSH() {
  printf("Initializing libssh using ssh_init()\n");
  ssh_threads_set_callbacks(ssh_threads_get_noop());
  ssh_init();
}

int shutdownLibSSH() {
  printf("Shutting down libssh using ssh_finalize()\n");
  return ssh_finalize();
}

int *scpFetchFile(const char *localName, const char *remoteName) {
  printf("SSH.c:scpFetchFile() Fetching file from '%s' to '%s'\n", remoteName, localName);
  //struct location *dest, *src;
  //dest=parse_location(localName);
  //if(open_location(dest,WRITE)<0)
   // return EXIT_FAILURE;

  // approach/test 1
  /*
  ssh_session session;
  session=connect_ssh("nas",NULL,verbosity);
  if(session == NULL)
    return EXIT_FAILURE;
  dest = parse_location((char *)localName);//"/tmp/bli");
  src  = parse_location((char *)remoteName);//"nas:/tmp/blub");
  do_copy(src, dest, 0);
  */

  // approach/test 2
  // reads recursive, but doesnt write yet
  /*
  ssh_session session;
  session=connect_ssh("nas",NULL,verbosity);
  if(session == NULL)
    return EXIT_FAILURE;
  fetch_files(session);
  ssh_disconnect(session);
  ssh_free(session);
  ssh_finalize();
  */
  
  // test remote exec
  // sshRemoteExec("nas","uptime -s | cut -d' ' -f2");
  
  return 0;
}

const char *getSSHCopyrightString(void) {
  return ssh_copyright(); // ssh_copyright is a libssh function
}

int fetch_files(ssh_session session){
  size_t size;
  char buffer[16384]; // libssh max 65536; setting it did not change chunksize ret'd from ssh_scp_read...?
  int mode;
  char *filename;
  int r,ret;
  ssh_scp scp=ssh_scp_new(session, SSH_SCP_READ | SSH_SCP_RECURSIVE, "/tmp/libssh_tests/*");
  if(ssh_scp_init(scp) != SSH_OK){
    fprintf(stderr,"error initializing scp: %s\n",ssh_get_error(session));
    ssh_scp_free(scp);
    return -1;
  }
  do {
    r=ssh_scp_pull_request(scp);
    switch(r){
      case SSH_SCP_REQUEST_NEWFILE:
        size=ssh_scp_request_get_size(scp);
        filename=strdup(ssh_scp_request_get_filename(scp));
        mode=ssh_scp_request_get_permissions(scp);
        printf("downloading file %s, size %d, perms 0%o\n",filename,(int)size,mode);
        free(filename);
        ssh_scp_accept_request(scp);
        double chunks = ceilf(((float)size/(float)sizeof(buffer)));
        printf("using %f chunks for %lu bytes sized buffer \n", chunks, sizeof(buffer));
        while ( (ret=ssh_scp_read(scp,buffer,sizeof(buffer))) > 0) {
          printf("SSH got ret: %d\n", ret);
          if(ret==SSH_ERROR){
            fprintf(stderr,"Error reading scp: %s\n",ssh_get_error(session));
            ssh_scp_close(scp);
            ssh_scp_free(scp);
            return -1;
          }
        }
        // yay, works ... but keep track of full path & create files...
        printf("done\n");
        break;
      case SSH_ERROR:
        fprintf(stderr,"Error: %s\n",ssh_get_error(session));
        ssh_scp_close(scp);
        ssh_scp_free(scp);
        return -1;
      case SSH_SCP_REQUEST_WARNING:
        fprintf(stderr,"Warning: %s\n",ssh_scp_request_get_warning(scp));
        break;
      case SSH_SCP_REQUEST_NEWDIR:
        filename=strdup(ssh_scp_request_get_filename(scp));
        mode=ssh_scp_request_get_permissions(scp);
        printf("downloading directory %s, perms 0%o\n",filename,mode);
        free(filename);
        ssh_scp_accept_request(scp);
        break;
      case SSH_SCP_REQUEST_ENDDIR:
        printf("End of directory\n");
        break;
      case SSH_SCP_REQUEST_EOF:
        printf("End of requests\n");
        goto end;
    }
  } while (1);
end:
  ssh_scp_close(scp);
  ssh_scp_free(scp);
  return 0;
}

int sshRemoteExec(const char *host, const char *command, const char* username) {
  ssh_session session;
  ssh_channel channel;
  char buffer[256];
  int nbytes;
  int rc;
  
  // this retval should be returned...
  //int *retval = malloc(sizeof *retval);
  // and back in swift,
  // CFfree(ptr) -- fixme, function currently returns int, not int*
  
  // printf("Executing on %s: '%s'\n", host, command);
  
  // retry silently? how to report back connect error vs exec error...?
  session = connect_ssh(host, username, 0);
  if (session == NULL) {
    //ssh_finalize();
    printf("OOOPS: no conn on %s (as %s)\n", host, username);
    return 1;
  }
  
  channel = ssh_channel_new(session);;
  if (channel == NULL) {
    ssh_disconnect(session);
    ssh_free(session);
    // ssh_finalize(); // docs say only at end of app...
    return 1;
  }
  
  rc = ssh_channel_open_session(channel);
  if (rc < 0) {
    goto failed;
  }
  
  rc = ssh_channel_request_exec(channel, command);
  if (rc < 0) {
    goto failed;
  }
  
  nbytes = ssh_channel_read(channel, buffer, sizeof(buffer), 0);
  while (nbytes > 0) {
    // fixme ... should be returned to swift
    if (fwrite(buffer, 1, nbytes, stdout) != (unsigned int) nbytes) {
      goto failed;
    }
    nbytes = ssh_channel_read(channel, buffer, sizeof(buffer), 0);
  }
  
  if (nbytes < 0) {
    goto failed;
  }
  
  ssh_channel_send_eof(channel);
  ssh_channel_close(channel);
  ssh_channel_free(channel);
  ssh_disconnect(session);
  ssh_free(session);
  
  return 0;
failed:
  ssh_channel_close(channel);
  ssh_channel_free(channel);
  ssh_disconnect(session);
  ssh_free(session);
  
  return 1;
}

int verify_knownhost(ssh_session session){
  char *hexa;
  int state;
  unsigned char *hash = NULL;
  size_t hlen;
  ssh_key srv_pubkey;
  int rc;
  
  state=ssh_is_server_known(session);
  
  rc = ssh_get_publickey(session, &srv_pubkey);
  if (rc < 0) {
    return -1;
  }
  
  rc = ssh_get_publickey_hash(srv_pubkey,
                              SSH_PUBLICKEY_HASH_SHA1,
                              &hash,
                              &hlen);
  ssh_key_free(srv_pubkey);
  if (rc < 0) {
    return -1;
  }
  
  switch(state){
    case SSH_SERVER_KNOWN_OK:
      break; /* ok */
    case SSH_SERVER_KNOWN_CHANGED:
      fprintf(stderr,"Host key for server changed : server's one is now :\n");
      ssh_print_hexa("Public key hash",hash, hlen);
      ssh_clean_pubkey_hash(&hash);
      fprintf(stderr,"For security reason, connection will be stopped\n");
      return -1;
    case SSH_SERVER_FOUND_OTHER:
      fprintf(stderr,"The host key for this server was not found but an other type of key exists.\n");
      fprintf(stderr,"An attacker might change the default server key to confuse your client"
              "into thinking the key does not exist\n"
              "We advise you to rerun the client with -d or -r for more safety.\n");
      return -1;
    case SSH_SERVER_FILE_NOT_FOUND:
      fprintf(stderr,"Could not find known host file. If you accept the host key here,\n");
      fprintf(stderr,"the file will be automatically created.\n");
      /* fallback to SSH_SERVER_NOT_KNOWN behavior */
    case SSH_SERVER_NOT_KNOWN:
      hexa = ssh_get_hexa(hash, hlen);
      fprintf(stderr,"The server is unknown. Trust must be established outside Examator! (ssh-keyscan!)\n");
      fprintf(stderr, "Public key hash: %s\n", hexa);
      ssh_string_free_char(hexa);
      ssh_clean_pubkey_hash(&hash);
      return -1;
      break;
    case SSH_SERVER_ERROR:
      ssh_clean_pubkey_hash(&hash);
      fprintf(stderr,"%s",ssh_get_error(session));
      return -1;
  }
  ssh_clean_pubkey_hash(&hash);
  return 0;
}

static void error(ssh_session session){
  fprintf(stderr,"Authentication failed: %s\n",ssh_get_error(session));
}

int authenticate_pubkey(ssh_session session){
  int rc;
  int method;
  
  // Try to authenticate
  rc = ssh_userauth_none(session, NULL);
  if (rc == SSH_AUTH_ERROR) {
    error(session);
    return rc;
  }
  
  method = ssh_userauth_list(session, NULL);
  // Try to authenticate with public key first
  if (method & SSH_AUTH_METHOD_PUBLICKEY) {
    rc = ssh_userauth_publickey_auto(session, NULL, NULL);
    if (rc == SSH_AUTH_ERROR) {
      error(session);
      return rc;
    } else if (rc == SSH_AUTH_SUCCESS) {
      // yippie it worked!
    }
  } else {
    printf("Yikes! the server does not support pubkey auth?\n");
  }
  
  return rc;
}

ssh_session connect_ssh(const char *host, const char *user,int verbosity){
  ssh_session session;
  int auth=0;
  
  session=ssh_new();
  if (session == NULL)
    return NULL;

  // http://api.libssh.org/master/group__libssh__session.html#ga7a801b85800baa3f4e16f5b47db0a73d
  //SSH_OPTIONS_IDENTITY: Set the identity file name (const char *,format string).
  //SSH_OPTIONS_TIMEOUT: Set a timeout for the connection in seconds (long).
  long timeout = 5;
  ssh_options_set(session, SSH_OPTIONS_TIMEOUT, &timeout);
  ssh_options_set(session, SSH_OPTIONS_USER, user);
  ssh_options_set(session, SSH_OPTIONS_HOST, host);
  ssh_options_set(session, SSH_OPTIONS_LOG_VERBOSITY, &verbosity);
  
  if(ssh_connect(session)){
    fprintf(stderr,"Connection failed : %s\n",ssh_get_error(session));
    ssh_disconnect(session);
    ssh_free(session);
    return NULL;
  }
  if(verify_knownhost(session)<0){
    ssh_disconnect(session);
    ssh_free(session);
    return NULL;
  }
  auth=authenticate_pubkey(session);
  if(auth==SSH_AUTH_SUCCESS){
    return session;
  } else if(auth==SSH_AUTH_DENIED){
    fprintf(stderr,"Pubkey-Auth failed, check hostkeys!\n");
  } else {
    fprintf(stderr,"Error while authenticating : %s\n",ssh_get_error(session));
  }
  ssh_disconnect(session);
  ssh_free(session);
  return NULL;
}

int do_copy(struct location *src, struct location *dest, int recursive){
  size_t size,r,w;
  socket_t fd;
  struct stat s;
  int ret;
  char buffer[16384];
  int total=0;
  int mode = 0;
  char *filename = NULL;
  /* recursive mode doesn't work yet */
  (void)recursive;
  /* Get the file name and size*/
  if(!src->is_ssh){
    fd = fileno(src->file);
    if (fd < 0) {
      fprintf(stderr, "Invalid file pointer, error: %s\n", strerror(errno));
      return -1;
    }
    ret = fstat(fd, &s);
    if (ret < 0) {
      return -1;
    }
    size=s.st_size;
    mode = s.st_mode & ~S_IFMT;
    filename=ssh_basename(src->path);
  } else {
    size=0;
    do {
      r=ssh_scp_pull_request(src->scp);
      if(r==SSH_SCP_REQUEST_NEWDIR){
        ssh_scp_deny_request(src->scp,"Not in recursive mode");
        continue;
      }
      if(r==SSH_SCP_REQUEST_NEWFILE){
        size=ssh_scp_request_get_size(src->scp);
        filename=strdup(ssh_scp_request_get_filename(src->scp));
        mode=ssh_scp_request_get_permissions(src->scp);
        //ssh_scp_accept_request(src->scp);
        break;
      }
      if(r==SSH_ERROR){
        fprintf(stderr,"Error !!!!!!!!!!!!!!!!!!!\n");
        //fprintf(stderr,"Error: %s\n",ssh_get_error(src->session));
        ssh_string_free_char(filename);
        return -1;
      }
    } while(r != SSH_SCP_REQUEST_NEWFILE);
  }
  
  if(dest->is_ssh){
    r=ssh_scp_push_file(dest->scp,src->path, size, mode);
    //  snprintf(buffer,sizeof(buffer),"C0644 %d %s\n",size,src->path);
    if(r==SSH_ERROR){
      fprintf(stderr,"error: %s\n",ssh_get_error(dest->session));
      ssh_string_free_char(filename);
      ssh_scp_free(dest->scp);
      return -1;
    }
  } else {
    if(!dest->file){
      dest->file=fopen(filename,"w");
      if(!dest->file){
        fprintf(stderr,"Cannot open %s for writing: %s\n",filename,strerror(errno));
        if(src->is_ssh)
          ssh_scp_deny_request(src->scp,"Cannot open local file");
        ssh_string_free_char(filename);
        return -1;
      }
    }
    if(src->is_ssh){
      ssh_scp_accept_request(src->scp);
    }
  }
  do {
    if(src->is_ssh){
      r=ssh_scp_read(src->scp,buffer,sizeof(buffer));
      if(r==SSH_ERROR){
        fprintf(stderr,"Error reading scp: %s\n",ssh_get_error(src->session));
        ssh_string_free_char(filename);
        return -1;
      }
      if(r==0)
        break;
    } else {
      r=fread(buffer,1,sizeof(buffer),src->file);
      if(r==0)
        break;
      if(r<sizeof(buffer)){
        fprintf(stderr,"Error reading file: %s\n",strerror(errno));
        ssh_string_free_char(filename);
        return -1;
      }
    }
    if(dest->is_ssh){
      w=ssh_scp_write(dest->scp,buffer,r);
      if(w == SSH_ERROR){
        fprintf(stderr,"Error writing in scp: %s\n",ssh_get_error(dest->session));
        ssh_scp_free(dest->scp);
        dest->scp=NULL;
        ssh_string_free_char(filename);
        return -1;
      }
    } else {
      w=fwrite(buffer,r,1,dest->file);
      if(w<=0){
        fprintf(stderr,"Error writing in local file: %s\n",strerror(errno));
        ssh_string_free_char(filename);
        return -1;
      }
    }
    total+=r;
    
  } while(total < size);
  ssh_string_free_char(filename);
  printf("wrote %d bytes\n",total);
  return 0;
}

int open_location(struct location *loc, int flag){
  if(loc->is_ssh && flag==WRITE){
    loc->session=connect_ssh(loc->host,loc->user,verbosity);
    if(!loc->session){
      fprintf(stderr,"Couldn't connect to %s\n",loc->host);
      return -1;
    }
    loc->scp=ssh_scp_new(loc->session,SSH_SCP_WRITE,loc->path);
    if(!loc->scp){
      fprintf(stderr,"error : %s\n",ssh_get_error(loc->session));
      return -1;
    }
    if(ssh_scp_init(loc->scp)==SSH_ERROR){
      fprintf(stderr,"error : %s\n",ssh_get_error(loc->session));
      ssh_scp_free(loc->scp);
      loc->scp = NULL;
      return -1;
    }
    return 0;
  } else if(loc->is_ssh && flag==READ){
    loc->session=connect_ssh(loc->host, loc->user,verbosity);
    if(!loc->session){
      fprintf(stderr,"Couldn't connect to %s\n",loc->host);
      return -1;
    }
    loc->scp=ssh_scp_new(loc->session,SSH_SCP_READ,loc->path);
    if(!loc->scp){
      fprintf(stderr,"error : %s\n",ssh_get_error(loc->session));
      return -1;
    }
    if(ssh_scp_init(loc->scp)==SSH_ERROR){
      fprintf(stderr,"error : %s\n",ssh_get_error(loc->session));
      ssh_scp_free(loc->scp);
      loc->scp = NULL;
      return -1;
    }
    return 0;
  } else {
    loc->file=fopen(loc->path,flag==READ ? "r":"w");
    if(!loc->file){
      if(errno==EISDIR){
        if(chdir(loc->path)){
          fprintf(stderr,"Error changing directory to %s: %s\n",loc->path,strerror(errno));
          return -1;
        }
        return 0;
      }
      fprintf(stderr,"Error opening %s: %s\n",loc->path,strerror(errno));
      return -1;
    }
    return 0;
  }
  return -1;
}
