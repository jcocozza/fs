package internal

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
)

const (
	Red   = "\033[31m"
	Reset = "\033[0m"

	contextWindow = 100
)

type SearchConfig struct {
	VersionControl       bool
	VersionControlIgnore bool
	Common				 bool
	IncludeMatchTags     bool
}

func searchFile(path, search string, includeMatchTags bool, wg *sync.WaitGroup, results chan<- string) {
	defer wg.Done()
	file, err := os.Open(path)
	if err != nil {
		return
	}

	b, err := checkFileBinary(path)
	if err != nil {
		return // don't panic
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
			start := max(0, idx-int(contextWindow/2))
			end := min(idx+int(contextWindow/2), len(line))

			// Create the trimmed line
			trimmedLine := line[start:end]

			if includeMatchTags {
				// Highlight the matched substring in the trimmed line
				trimmedLine = re.ReplaceAllString(trimmedLine, "<match>$0</match>")
			}
			if strings.HasSuffix(trimmedLine, "\n") {
				results <- fmt.Sprintf("%s:%d: %s", path, ln, trimmedLine)
			} else {
				results <- fmt.Sprintf("%s:%d: %s\n", path, ln, trimmedLine)
			}
		}
		ln++
	}
}

func Searcher(searchDir, search string, cfg SearchConfig) int {
	ig, err := ReadIgnoreFiles(searchDir, cfg.VersionControl, cfg.VersionControlIgnore, cfg.Common)
	if err != nil {
		panic(err)
	}
	var wg sync.WaitGroup
	results := make(chan string)

	go func() {
		for result := range results {
			fmt.Print(result)
		}
	}()

	var fileCnt int
	_ = filepath.Walk(searchDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			fmt.Println(err.Error())
			return nil
		}

		if !info.IsDir() {
			if ig.Isin(path) {
				return nil
			}
			wg.Add(1)
			go searchFile(path, search, cfg.IncludeMatchTags, &wg, results)
			fileCnt++
		} else {
			if ig.Isin(path) {
				return filepath.SkipDir
			}
		}
		return nil
	})

	wg.Wait()
	close(results)
	return fileCnt
	//fmt.Printf("total files searched: %d\n", fileCnt)
}
