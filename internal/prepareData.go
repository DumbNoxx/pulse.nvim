package internal

import "crypto/rand"

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
