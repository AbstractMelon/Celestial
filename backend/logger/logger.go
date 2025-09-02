package logger

import (
	"log"
	"os"
)

var (
	DebugEnabled = false

	infoLog  = log.New(os.Stdout, "[INFO] ", log.LstdFlags)
	errorLog = log.New(os.Stderr, "[ERROR] ", log.LstdFlags)
	debugLog = log.New(os.Stdout, "[DEBUG] ", log.LstdFlags|log.Lshortfile)
)

func Info(v ...any) {
	infoLog.Println(v...)
}

func Error(v ...any) {
	errorLog.Println(v...)
}

func Debug(v ...any) {
	if DebugEnabled {
		debugLog.Println(v...)
	}
}
