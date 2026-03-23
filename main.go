package main

import (
	"bufio"
	"crypto/tls"
	"fmt"
	"os"
	"regexp"
	"time"

	"github.com/DumbNoxx/pulse.nvim/internal"
)

var (
	re = regexp.MustCompile(`:\d{1,4}`)
)

func handleIdleTimeout(key string, url string) {
	ticker := time.NewTicker(time.Second * 30)
	defer ticker.Stop()
	for range ticker.C {
		if err := internal.Heartbeat(key, url); err != nil {
			fmt.Println(err)
			continue
		}
	}
}

func cleanUrl(url string) string {
	return re.ReplaceAllString(url, "")
}

func main() {
	var (
		err           error
		serverAddr    string
		validateToken string
		isLocalhost   bool
		config        *tls.Config
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
	conn := internal.HandleWs(serverAddr, err, validateToken, isLocalhost, config)
	defer conn.Close()

	scanner := bufio.NewScanner(os.Stdin)
	go handleIdleTimeout(validateToken, fmt.Sprintf("https://%s", cleanUrl(serverAddr)))
	for scanner.Scan() {
		line := scanner.Bytes()
		if len(line) == 0 {
			continue
		}

		frame := internal.PrepareData(line)
		_, err := conn.Write(frame)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Write error: %v\n", err)
			os.Exit(1)
		}
	}
}
