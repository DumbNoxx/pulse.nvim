package internal

import (
	"fmt"
	"net/http"
	"time"
)

func Heartbeat(key string, url string) error {
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return err
	}
	req.Header.Set("AUTH", "Bearer"+key)
	client := &http.Client{
		Timeout: 10 * time.Second,
	}
	resp, err := client.Do(req)
	if resp.StatusCode > 299 {
		return fmt.Errorf("response failed with status code: %d and \nbody: %s\n", resp.StatusCode, resp.Body)
	}
	defer resp.Body.Close()
	if err != nil {
		return err
	}
	return nil
}
