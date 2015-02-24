//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

const char *getSSHCopyrightString(void);

void initLibSSH();
int shutdownLibSSH();

// execute command on remote.
// should be extended to return retval+retString (by ref, mem?)
int sshRemoteExec(const char *host, const char *command, const char* username);

// should be scpFetchResourc(supporting file or dir)
int *scpFetchFile(const char* localName, const char* remoteName);

// add:
// sshPushResource(dir or file, targetHost, targetPath, username)