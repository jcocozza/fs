package internal

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sync"
)

const (
	Red = "\033[31m"
	Reset = "\033[0m"
)

func searchFile(path, search string, wg *sync.WaitGroup, results chan<- string) {
	defer wg.Done()
	file, err := os.Open(path)
	if err != nil {
		return
	}

	scanner := bufio.NewScanner(file)
	re := regexp.MustCompile(search)
	ln := 1

	for scanner.Scan() {
		line := scanner.Bytes()
		if re.Match(line) {
			//highlighted := re.ReplaceAllString(string(line), Red + "$0" + Reset)
			highlighted := re.ReplaceAllString(string(line), "<match>" + "$0" + "</match>")
			results <- fmt.Sprintf("%s:%d: %s\n", path, ln, highlighted)
			//results <- fmt.Sprintf("%s:%d: %s\n", path, ln, line)
		}
		ln++
	}

	if err := scanner.Err(); err != nil {
		results <- fmt.Sprintf("Error reading file %s: %v", path, err)
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
			b, err := isBinary(path)
			if err != nil {
				fmt.Println(err.Error())
				return nil
			}
			if !b {
				wg.Add(1)
				go searchFile(path, search, &wg, results)
				fileCnt++
			}
		}
		return nil
	})

	wg.Wait()
	close(results)
	return fileCnt
	//fmt.Printf("total files searched: %d\n", fileCnt)
}
