package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/jcocozza/fs/internal"
)

func main() {
	pattern := flag.String("pattern", "", "regex search pattern")
	path := flag.String("path", ".", "the directory to search")
	versionControl := flag.Bool("version-control", true, "ignore folders like .git/.svn")
	versionControlIgnore := flag.Bool("version-control-ignore", true, "ignore files contained in files like .gitignore/.hgignore")
	includeMatchTags := flag.Bool("match-tags", true, "include <match></match> around matched patterns in the result set")
	common := flag.Bool("common", true, fmt.Sprintf("ignore other commonly ignored folders/files: %v", internal.CommonIgnore))
	flag.Parse()

	if *pattern == "" {
		os.Exit(1)
	}

	cfg := internal.SearchConfig{
		VersionControl:       *versionControl,
		VersionControlIgnore: *versionControlIgnore,
		IncludeMatchTags:     *includeMatchTags,
		Common:               *common,
	}

	//fmt.Println("searching for: " + *pattern + " in " + *path)
	internal.Searcher(*path, *pattern, cfg)
}
