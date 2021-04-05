package user

type ExecUser struct {
	Uid   int
	Gid   int
	Sgids []int
	Home  string
}

func Test() {
	//#fonction test
}