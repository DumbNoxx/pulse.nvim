package internal

import (
	"bufio"
	"crypto/rand"
	"crypto/tls"
	"encoding/base64"
	"fmt"
	"net"
	"os"
	"strings"
)

func HandleWs(serverAddr string, err error, validateToken string, isLocalhost bool, config *tls.Config) (conn net.Conn) {
	hostOnly := serverAddr
	if strings.Contains(serverAddr, ":") {
		hostOnly, _, _ = net.SplitHostPort(serverAddr)
	}
	if isLocalhost {
		conn, err = net.Dial("tcp", serverAddr)
	} else {
		config = &tls.Config{ServerName: hostOnly, InsecureSkipVerify: isLocalhost}
		conn, err = tls.Dial("tcp", serverAddr, config)
	}
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error connection: %v\n", err)
		os.Exit(1)
	}

	key := make([]byte, 16)
	rand.Reader.Read(key)
	strKey := base64.StdEncoding.EncodeToString(key)
	path := fmt.Sprintf("/ws?token=%s", validateToken)
	fmt.Fprintf(conn,
		"GET %s HTTP/1.1\r\nHost: %s\r\nUpgrade: %s\r\nConnection: %s\r\nSec-WebSocket-Key: %s\r\nSec-WebSocket-Version: 13\r\nValidate: %s\r\n\r\n",
		path,
		hostOnly,
		"websocket",
		"Upgrade",
		strKey,
		validateToken,
	)
	res := bufio.NewReader(conn)
	statusLine, err := res.ReadString('\n')
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading response: %v\n", err)
		os.Exit(1)
	}
	if !strings.Contains(statusLine, "HTTP/1.1 101 Switching Protocols") {
		fmt.Fprintf(os.Stderr, "Server rejected upgrade: %s", statusLine)
		os.Exit(1)
	}

	for {
		line, _ := res.ReadString('\n')
		if line == "\r\n" || line == "\n" {
			break
		}
	}
	fmt.Println("Connect to Websocket")
	return
}
