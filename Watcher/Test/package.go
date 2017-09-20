package test

import "fmt"

type Example struct {
	somefield int
}

func New() *Example {
	test := &Example{1}
	fmt.Println(test)
	return test
}
