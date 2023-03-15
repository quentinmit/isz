package linkzone

import (
	"bytes"
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/md5"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"math/rand"
	"net/http"
	"strconv"
	"strings"

	"github.com/AdamSLevy/jsonrpc2/v14"
	"github.com/zenazn/pkcs7pad"
)

type Client struct {
	address string
	c       *jsonrpc2.Client
}

const keyHeader = "_TclRequestVerificationKey"
const tokenHeader = "_TclRequestVerificationToken"

func NewClient(address string) *Client {
	c := &jsonrpc2.Client{
		Header: http.Header{
			keyHeader: []string{"KSDHSDFOGQ5WERYTUIQWERTYUISDFG1HJZXCVCXBN2GDSMNDHKVKFsVBNf"},
			"Referer": []string{fmt.Sprintf("http://%s/", address)},
		},
	}
	return &Client{
		address: address,
		c:       c,
	}
}

func encrypt(input string) string {
	// from the javascript
	const phrase = "e5dl12XYVggihggafXWf0f2YSf2Xngd1"
	// (a[2 * n] = (240 & t[n % t.length].charCodeAt()) | ((15 & r) ^ (15 & t[n % t.length].charCodeAt()))), (a[2 * n + 1] = (240 & t[n % t.length].charCodeAt()) | ((r >> 4) ^ (15 & t[n % t.length].charCodeAt())));
	var out strings.Builder
	for idx, r := range []byte(input) {
		positioncode := phrase[idx%len(phrase)]
		out.WriteByte((240 & positioncode) | ((15 & r) ^ (15 & positioncode)))
		out.WriteByte((240 & positioncode) | ((r >> 4) ^ (15 & positioncode)))
	}
	return out.String()
}

func encrypt_c(input string, key, iv []byte) (string, error) {
	return ens_a(encrypt(input), key, iv)
}

func encrypt_u(input string) string {
	return fmt.Sprintf("%x", md5.Sum([]byte(input)))
}

func ens_a(input string, key, iv []byte) (string, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}
	mode := cipher.NewCBCEncrypter(block, iv)
	buf := pkcs7pad.Pad([]byte(input), len(key))
	ciphertext := make([]byte, len(buf))
	mode.CryptBlocks(ciphertext, buf)
	return base64.StdEncoding.EncodeToString(ciphertext), nil
}

type GetLoginStateResponse struct {
	PwEncrypt           int
	State               int
	LoginRemainingTimes int
	LockedRemainingTime int
}

type loginResponse struct {
	Token  string `json:"token"`
	Param0 string `json:"param0"`
	Param1 string `json:"param1"`
}

func (l loginResponse) HeaderToken() (string, error) {
	if l.Param0 != "" {
		return encrypt_c(l.Token, []byte(l.Param0), []byte(l.Param1))
	}
	return encrypt(l.Token), nil
}

func (c *Client) GetLoginState(ctx context.Context) (*GetLoginStateResponse, error) {
	var resp GetLoginStateResponse
	if err := c.Request(ctx, "GetLoginState", nil, &resp); err != nil {
		return nil, err
	}
	return &resp, nil
}

func (c *Client) Login(ctx context.Context, user, password string) error {
	glsresp, err := c.GetLoginState(ctx)
	if err != nil {
		return err
	}
	log.Printf("Login state: %+v", glsresp)
	var result loginResponse
	u := encrypt(user)
	p := encrypt(password)
	if glsresp.PwEncrypt != 0 { // isSupportEncM
		p = encrypt_u(password)
	}
	log.Printf("UserName: %q Password: %q", u, p)
	if err := c.Request(ctx, "Login", map[string]string{
		"UserName": u,
		"Password": p,
	}, &result); err != nil {
		return err
	}
	log.Printf("login response: %+v", result)
	token, err := result.HeaderToken()
	if err != nil {
		return err
	}
	c.c.Header[tokenHeader] = []string{token}
	return nil
}

func (c *Client) Request(ctx context.Context, method string,
	params, result interface{}) error {

	// Generate a psuedo random ID for this request.
	reqID := strconv.Itoa(rand.Int()%5000 + 1)

	// Marshal the JSON RPC Request.
	req := jsonrpc2.Request{ID: reqID, Method: method, Params: params}
	reqData, err := req.MarshalJSON()
	if err != nil {
		return err
	}

	// Compose the HTTP request.
	httpReq, err := http.NewRequest(
		http.MethodPost,
		fmt.Sprintf("http://%s/jrd/webapi", c.address),
		bytes.NewBuffer(reqData))
	if err != nil {
		return err
	}
	if ctx != nil {
		httpReq = httpReq.WithContext(ctx)
	}
	httpReq.Header.Add(http.CanonicalHeaderKey("Content-Type"), "application/json")
	for k, v := range c.c.Header {
		httpReq.Header[http.CanonicalHeaderKey(k)] = v
	}
	if c.c.BasicAuth {
		httpReq.SetBasicAuth(c.c.User, c.c.Password)
	}

	// Make the request.
	httpRes, err := c.c.Do(httpReq)
	if err != nil {
		return err
	}
	defer httpRes.Body.Close()
	body, err := io.ReadAll(httpRes.Body)
	if err != nil {
		return err
	}

	// Unmarshal the HTTP response into a JSON RPC response.
	var resID string
	var raw json.RawMessage
	res := jsonrpc2.Response{Result: &raw, ID: &resID}
	d := json.NewDecoder(bytes.NewReader(body))
	if err := d.Decode(&res); err != nil {
		return fmt.Errorf("parsing jsonrpc2 response %v: %w", string(body), err)
	}
	d = json.NewDecoder(bytes.NewReader(raw))
	d.UseNumber()
	if err := d.Decode(result); err != nil {
		return fmt.Errorf("parsing %v: %w", raw, err)
	}
	if res.HasError() {
		return res.Error
	}

	return nil
}
