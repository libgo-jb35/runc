package user

import (
	"fmt"
)

type ExecUser struct {
	Uid   int
	Gid   int
	Sgids []int
	Home  string
}

func Test() {
	fmt.Println("user.go:Test")
	//#fonction test
}