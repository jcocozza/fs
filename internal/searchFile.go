package internal

import (
	"bufio"
	"strings"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sync"
)
const (
	Red = "\033[31m"
	Reset = "\033[0m"

	contextWindow = 100
)

func searchFile(path, search string, wg *sync.WaitGroup, results chan<- string) {
	defer wg.Done()
	file, err := os.Open(path)
	if err != nil {
		return
	}

	b, err := checkFileBinary(path)
	if err != nil {
		panic(err)
	}
	if b {
		return
	}

	re := regexp.MustCompile(search)
	ln := 1

	reader := bufio.NewReader(file)
	for {
		line, err := reader.ReadString('\n')
		if err != nil {
			return
		}
		if re.MatchString(line) {
			// Find the matched substring
            match := re.FindStringSubmatch(line)[0]
            idx := strings.Index(line, match)
			start := max(0, idx - int(contextWindow / 2))
			end := min(idx + int(contextWindow / 2), len(line))

            // Create the trimmed line
            trimmedLine := line[start:end]

            // Highlight the matched substring in the trimmed line
            highlighted := re.ReplaceAllString(trimmedLine, "<match>$0</match>")
			if strings.HasSuffix(trimmedLine, "\n") {
				results <- fmt.Sprintf("%s:%d: %s", path, ln, highlighted)
			} else {
				results <- fmt.Sprintf("%s:%d: %s\n", path, ln, highlighted)
			}
		}
		ln++
	}
}

func Searcher(searchDir, search string) int {
	var wg sync.WaitGroup
	results := make(chan string)

	go func() {
		for result := range results {
			fmt.Print(result)
		}
	}()

	var fileCnt int
	filepath.Walk(searchDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			fmt.Println(err.Error())
			return nil
		}
		if !info.IsDir() {
			wg.Add(1)
			go searchFile(path, search, &wg, results)
			fileCnt++
		}
		return nil
	})

	wg.Wait()
	close(results)
	return fileCnt
	//fmt.Printf("total files searched: %d\n", fileCnt)
}
