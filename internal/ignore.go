package internal

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"regexp"
)

const (
	fsignore  string = ".fsignore"
	git       string = ".git"
	gitignore string = ".gitignore"
	mercurial string = ".hg"
	hgignore  string = ".hgignore"
	svn       string = ".svn"
)

// some common things to ignore
var CommonIgnore = []string{
	// python
	"venv",
	"__pycache__",
	// javascript
	"node_modules",
	// mac_os
	".DS_Store",
	// other
	".swp",
	".tmp",
	// svelte
	".svelte-kit",
}

// A set of regular expressions to ignore
type IgnoreFiles []*regexp.Regexp

// From a list of patterns to ignore create a list of regex patterns
func createIgnoreFiles(patterns []string) (IgnoreFiles, error) {
	f := make(IgnoreFiles, len(patterns))
	for i, p := range patterns {
		exp, err := regexp.Compile(p)
		if err != nil {
			return nil, err
		}
		f[i] = exp
	}
	return f, nil
}

// check if a string matches any of the ignore patterns
func (f IgnoreFiles) Isin(pattern string) bool {
	for _, exp := range f {
		if exp.MatchString(pattern) {
			return true
		}
	}
	return false
}

func readIgnoreFile(path string) ([]string, error) {
	patterns := []string{}

	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}

	reader := bufio.NewReader(file)
	for {
		line, err := reader.ReadString('\n')
		if err != nil {
			if err == io.EOF {
				break
			}
			return nil, err
		}
		// each line will be a different file path/pattern
		patterns = append(patterns, line)
	}
	return patterns, nil
}

// read ignore files
//
// - will always check for a .fsignore file (this essentially operates as a .gitignore file)
// - versionControl will ignore version control folders like .git
// - versionControlIgnore will ignore the files/patterns contained in files like .gitignore
func ReadIgnoreFiles(root string, versionControl bool, versionControlIgnore bool, common bool) (IgnoreFiles, error) {
	patterns := []string{}

	fsignorePatterns, _ := readIgnoreFile(fmt.Sprintf("%s/%s", root, fsignore))
	patterns = append(patterns, fsignorePatterns...)
	if versionControl {
		// ignore the versioning folders
		patterns = append(patterns, []string{git, mercurial, svn}...)
	}
	if versionControlIgnore {
		// check for git
		gitignorePatterns, _ := readIgnoreFile(fmt.Sprintf("%s/%s", root, gitignore))
		patterns = append(patterns, gitignorePatterns...)
		hgignorePatterns, _ := readIgnoreFile(fmt.Sprintf("%s/%s", root, hgignore))
		patterns = append(patterns, hgignorePatterns...)
	}

	if common {
		patterns = append(patterns, CommonIgnore...)
	}

	return createIgnoreFiles(patterns)
}
