package user

import (
	"fmt"
)

// Unix-specific path to the passwd and group formatted files.
const (
	unixPasswdPath = "/etc/passwd"
	unixGroupPath  = "/etc/group"
)

func GetPasswdPath() (string, error) {
	return unixPasswdPath, nil
}