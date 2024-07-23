package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/jcocozza/vssr/internal"
)

func main() {
    pattern := flag.String("pattern", "", "regex search pattern")
    path := flag.String("path", ".", "the directory to search")
    flag.Parse()

    if *pattern == "" {
        os.Exit(1)
    }


    fmt.Println("searching for: " + *pattern + " in " + *path)
    internal.Searcher(*path, *pattern)
}
