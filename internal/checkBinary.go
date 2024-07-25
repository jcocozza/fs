package internal

import (
	"os"
	"bytes"
)

const (
	readSize = 512
)

// this is basically copied directly from:  https://github.com/ggreer/the_silver_searcher/blob/a61f1780b64266587e7bc30f0f5f71c6cca97c0f/src/util.c#L333
// isBinary determines if the given buffer is binary data or text.
func isBinary(buf []byte) bool {
	bufLen := len(buf)
	suspiciousBytes := 0
	totalBytes := bufLen
	if totalBytes > readSize {
		totalBytes = readSize
	}

	if bufLen == 0 {
		// An empty buffer; it's not clear if it's binary or text.
		return false
	}

	// Check for UTF-8 BOM
	if bufLen >= 3 && buf[0] == 0xEF && buf[1] == 0xBB && buf[2] == 0xBF {
		return false
	}

	// Check for PDF magic number
	if bufLen >= 5 && bytes.HasPrefix(buf, []byte("%PDF-")) {
		return true
	}

	for i := 0; i < totalBytes; i++ {
		if buf[i] == 0 {
			// NULL character indicates binary data.
			return true
		} else if (buf[i] < 7 || buf[i] > 14) && (buf[i] < 32 || buf[i] > 127) {
			// UTF-8 detection
			if buf[i] > 193 && buf[i] < 224 && i+1 < totalBytes {
				i++
				if buf[i] > 127 && buf[i] < 192 {
					continue
				}
			} else if buf[i] > 223 && buf[i] < 240 && i+2 < totalBytes {
				i++
				if buf[i] > 127 && buf[i] < 192 && buf[i+1] > 127 && buf[i+1] < 192 {
					i++
					continue
				}
			}
			suspiciousBytes++
			// Check if at least 32 bytes are read and suspicious bytes exceed 10%
			if i >= 32 && (suspiciousBytes*100)/totalBytes > 10 {
				return true
			}
		}
	}
	return (suspiciousBytes*100) / totalBytes > 10
}

// checkFileBinary checks if the file at the given path is binary.
func checkFileBinary(filePath string) (bool, error) {
	// Read the file content
	buf, err := os.ReadFile(filePath)
	if err != nil {
		return false, err
	}

	// Check if the buffer is binary
	return isBinary(buf), nil
}
