//
//  SSHGitCommand.swift
//  SparkleShare-Mac
//
//  Created by Stefan Bethge on 23.09.24.
//

func formatGitSSHCommand(authInfo: SSHAuthenticationInfo) -> String {
    let sshCommandPath = "/usr/bin/ssh" // Modify this to your SSH path if different
    let command = """
    \(sshCommandPath) \
    -i \"\(authInfo.privateKeyFilePath)\" \
    -o UserKnownHostsFile=\"\(authInfo.knownHostsFilePath)\" \
    -o IdentitiesOnly=yes \
    -o PasswordAuthentication=no \
    -F /dev/null
    """
    return command
}


