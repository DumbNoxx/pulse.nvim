package main

import (
	"bufio"
	"crypto/tls"
	"fmt"
	"os"

	"github.com/DumbNoxx/pulse.nvim/internal"
)

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
