package main

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

func PrepareData(json []byte) (data []byte) {
	data = append(data, 0x81)
	if len(json) < 126 {
		data = append(data, 0x80+byte(len(json)))
	}

	key := make([]byte, 4)
	rand.Reader.Read(key)
	data = append(data, key...)

	for i := range json {
		data = append(data, byte(json[i]^key[i%4]))
	}

	return
}

func main() {
	var (
		conn          net.Conn
		err           error
		serverAddr    string
		validateToken string
		isLocalhost   bool
	)

	if len(os.Args) > 1 {
		if os.Args[1] == "" {
			return
		}
		serverAddr = os.Args[1]
	}

	validateToken = ""
	if len(os.Args) > 2 {
		validateToken = os.Args[2]
	}

	if len(os.Args) > 3 {
		if os.Args[3] == "true" {
			isLocalhost = true
		}
	}
	hostOnly := serverAddr
	if strings.Contains(serverAddr, ":") {
		hostOnly, _, _ = net.SplitHostPort(serverAddr)
	}
	var config *tls.Config
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
		serverAddr,
		"websocket",
		"Upgrade",
		strKey,
		validateToken,
	)
	res := bufio.NewReader(conn)
	line, err := res.ReadString('\n')
	if err != nil {
		panic(err)
	}
	if strings.TrimSpace(line) != "HTTP/1.1 101 Switching Protocols" {
		fmt.Println("error headers")
		panic("Error headers")
	}
	fmt.Println("Connect to Websocket")
	scanner := bufio.NewScanner(os.Stdin)
	for scanner.Scan() {
		line := scanner.Text()
		fmt.Fprintf(conn, "%s", PrepareData([]byte(line)))
	}
}
