package internal

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
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
	".vim",
	".swp",
	".tmp",
	".oh-my-zsh",
	// svelte
	".svelte-kit",
}

// A set of filematch expressions to ignore
type IgnoreFiles []string

// check if a string matches any of the ignore patterns
//
// will ignore all malformed patterns
func (f IgnoreFiles) Isin(pattern string) bool {
	for _, exp := range f {
		matched, err := filepath.Match(exp, pattern)
		if err != nil {
			return false
		}
		if matched {
			return true
		}
	}
	return false
}

// return a string for each non-empty/non-comment line of a .ignore type file
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
		if strings.TrimSpace(line) == "" || strings.HasPrefix(line, "#") {
			continue
		}
		patterns = append(patterns, strings.TrimSpace(line))
	}
	return patterns, nil
}

// read ignore files
//
// - will always check for a .fsignore file (this essentially operates as a .gitignore file)
// - versionControl will ignore version control folders like .git
// - versionControlIgnore will ignore the files/patterns contained in files like .gitignore
func ReadIgnoreFiles(root string, versionControl bool, versionControlIgnore bool, common bool) IgnoreFiles {
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
	return patterns
}
