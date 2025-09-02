package main

import (
	"celestial-backend/config"
	"celestial-backend/logger"
	"celestial-backend/server"
	"flag"
	"log"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
)

const (
	DefaultConfigPath = "./config/config.json"
	DefaultMission    = "./missions/tutorial.lua"
)

func main() {
	configPath := flag.String("config", DefaultConfigPath, "Path to configuration file")
	missionFile := flag.String("mission", "", "Mission file to load on startup")
	debug := flag.Bool("debug", false, "Enable debug mode")
	flag.Parse()

	if *debug {
		logger.DebugEnabled = true
	}

	log.Println("Celestial Bridge Simulator Backend")
	log.Println("===================================")

	cfg, err := config.Load(*configPath)
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	if *debug {
		cfg.Logging.Level = "debug"
	}

	log.Printf("Configuration loaded from: %s", *configPath)

	if err := createDirectories(cfg); err != nil {
		log.Fatalf("Failed to create directories: %v", err)
	}

	srv := server.NewServer(cfg)

	if err := srv.Start(); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}

	if *missionFile != "" {
		log.Printf("Loading mission: %s", *missionFile)
		if err := srv.LoadMission(*missionFile); err != nil {
			log.Printf("Failed to load mission %s: %v", *missionFile, err)
		}
	} else if cfg.Missions.AutoLoad && cfg.Missions.DefaultMission != "" {
		defaultMissionPath := filepath.Join(cfg.Missions.ScriptsPath, cfg.Missions.DefaultMission)
		log.Printf("Auto-loading default mission: %s", defaultMissionPath)
		if err := srv.LoadMission(defaultMissionPath); err != nil {
			log.Printf("Failed to load default mission: %v", err)
		}
	}

	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)

	log.Println("Server is running. Press Ctrl+C to stop.")
	<-c

	log.Println("Shutdown signal received")
	if err := srv.Stop(); err != nil {
		log.Printf("Error during shutdown: %v", err)
	}

	log.Println("Server stopped gracefully")
}

func createDirectories(cfg *config.Config) error {
	dirs := []string{
		cfg.Missions.ScriptsPath,
		filepath.Dir(cfg.Logging.OutputFile),
		cfg.Server.StaticFilesPath,
		"./config",
	}

	for _, dir := range dirs {
		if dir != "" && dir != "." {
			if err := os.MkdirAll(dir, 0755); err != nil {
				return err
			}
		}
	}

	return nil
}
