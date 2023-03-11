package linkzone

import "testing"

func TestEncrypt(t *testing.T) {
	if got, want := encrypt("admin"), "dc13ibej?7"; got != want {
		t.Errorf("got %q, want %q", got, want)
	}
}

func TestEncryptC(t *testing.T) {
	// token := "313cdf3a5be1040d"
	// param0 := "nU9S60qcysQiQOYb"
	// param1 := "1Vyg34jOW731p96b"
	// want := "WcuF3PIg/MI7sYfOw9qNHIdmvhWRvbLEaGoNfTqjGwiLJPtgNlswVbEqhqo2jBde"

	param0 := "q4Jc197GFk58rnqW"
	param1 := "fG7e9BOY5233ijXH"
	token := "6d421b324095c5f4"
	want := "GHH23on1pD7H07rlARYQcqn6fkhtuPIaLJh54a0Ox5Qh2Z4BCE4IHNOk+cU22rze"
	got, err := encrypt_c(token, []byte(param0), []byte(param1))
	if err != nil {
		t.Errorf("got error %v", err)
	}
	if got != want {
		t.Errorf("got %q, want %q", got, want)
	}
}
