package server

import (
	"celestial-backend/config"
	"celestial-backend/networking"
	"celestial-backend/panels"
	"celestial-backend/scripting"
	"celestial-backend/stations"
	"celestial-backend/universe"
	"context"
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"
)

type Server struct {
	config         *config.Config
	universe       *universe.Universe
	stationManager *stations.StationManager
	panelManager   *panels.PanelManager
	luaEngine      *scripting.LuaEngine
	wsServer       *WebSocketServer
	tcpServer      *TCPServer
	httpServer     *http.Server
	running        bool
	mutex          sync.RWMutex
	ctx            context.Context
	cancel         context.CancelFunc
}

func NewServer(cfg *config.Config) *Server {
	ctx, cancel := context.WithCancel(context.Background())

	u := universe.NewUniverse()
	stationManager := stations.NewStationManager(u)
	panelManager := panels.NewPanelManager(stationManager)
	luaEngine := scripting.NewLuaEngine(u)
	wsServer := NewWebSocketServer(stationManager)
	tcpServer := NewTCPServer(panelManager)

	server := &Server{
		config:         cfg,
		universe:       u,
		stationManager: stationManager,
		panelManager:   panelManager,
		luaEngine:      luaEngine,
		wsServer:       wsServer,
		tcpServer:      tcpServer,
		running:        false,
		ctx:            ctx,
		cancel:         cancel,
	}

	server.setupCallbacks()
	return server
}

func (s *Server) setupCallbacks() {
	s.panelManager.AddOutputCallback(func(panelID string, output *networking.PanelOutputData) {
		s.tcpServer.SendOutputToPanel(panelID, output)
	})

	s.universe.AddEventCallback(func(eventType string, data interface{}) {
		s.handleUniverseEvent(eventType, data)
	})
}

func (s *Server) Start() error {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	if s.running {
		return nil
	}

	log.Printf("Starting Celestial Bridge Simulator Server...")

	if err := s.tcpServer.Start(s.config.Server.TCPPort); err != nil {
		return err
	}

	s.httpServer = &http.Server{
		Addr:         s.config.GetServerAddress(),
		ReadTimeout:  time.Duration(s.config.Server.ReadTimeout) * time.Second,
		WriteTimeout: time.Duration(s.config.Server.WriteTimeout) * time.Second,
	}

	s.setupHTTPRoutes()

	go func() {
		if err := s.httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Printf("HTTP server error: %v", err)
		}
	}()

	go s.wsServer.Run()
	go s.gameLoop()
	go s.broadcastLoop()

	s.running = true
	log.Printf("Server started on %s (WebSocket) and %s (TCP)",
		s.config.GetServerAddress(), s.config.GetTCPAddress())

	return nil
}

func (s *Server) Stop() error {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	if !s.running {
		return nil
	}

	log.Println("Stopping Celestial Bridge Simulator Server...")

	s.cancel()

	if s.httpServer != nil {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		s.httpServer.Shutdown(ctx)
	}

	s.tcpServer.Stop()
	s.luaEngine.Close()

	s.running = false
	log.Println("Server stopped")

	return nil
}

func (s *Server) setupHTTPRoutes() {
	mux := http.NewServeMux()

	mux.HandleFunc("/ws", s.wsServer.HandleWebSocket)
	mux.HandleFunc("/status", s.handleStatus)
	mux.HandleFunc("/api/universe/state", s.handleUniverseState)
	mux.HandleFunc("/api/stations", s.handleStations)
	mux.HandleFunc("/api/panels", s.handlePanels)
	mux.HandleFunc("/api/missions", s.handleMissions)
	mux.HandleFunc("/api/config", s.handleConfig)

	if s.config.Server.StaticFilesPath != "" {
		fs := http.FileServer(http.Dir(s.config.Server.StaticFilesPath))
		mux.Handle("/", fs)
	}

	if s.config.Server.EnableCORS {
		s.httpServer.Handler = http.HandlerFunc(corsMiddleware(mux.ServeHTTP))
	} else {
		s.httpServer.Handler = mux
	}
}

func (s *Server) gameLoop() {
	ticker := time.NewTicker(s.config.GetTickDuration())
	defer ticker.Stop()

	for {
		select {
		case <-s.ctx.Done():
			return
		case <-ticker.C:
			s.universe.Update()
			s.luaEngine.Update(s.config.GetTickDuration().Seconds())
		}
	}
}

func (s *Server) broadcastLoop() {
	ticker := time.NewTicker(s.config.GetStateUpdateDuration())
	defer ticker.Stop()

	for {
		select {
		case <-s.ctx.Done():
			return
		case <-ticker.C:
			state := s.universe.GetState()
			stateUpdate := &networking.StateUpdateData{
				Objects: state.Objects,
				Effects: state.Effects,
				Meta: map[string]interface{}{
					"time_acceleration": state.TimeAcceleration,
					"alert_level":       state.AlertLevel,
					"player_ship_id":    state.PlayerShipID,
				},
			}
			s.wsServer.BroadcastStateUpdate(stateUpdate)
		}
	}
}

func (s *Server) handleUniverseEvent(eventType string, data interface{}) {
	switch eventType {
	case "collision":
		if collision, ok := data.(universe.CollisionResult); ok {
			s.updatePanelLighting(collision)
		}
	case "alert_level_changed":
		if level, ok := data.(int); ok {
			s.updateAlertLighting(level)
		}
	case "object_destroyed":
		if objectID, ok := data.(string); ok {
			log.Printf("Object destroyed: %s", objectID)
		}
	}
}

func (s *Server) updatePanelLighting(collision universe.CollisionResult) {
	if collision.Object1.IsPlayerShip || collision.Object2.IsPlayerShip {
		s.panelManager.SetRGBStrip("captain_console", "bridge_lights", [][3]float64{{1.0, 0.0, 0.0}})
		time.AfterFunc(2*time.Second, func() {
			s.panelManager.SetRGBStrip("captain_console", "bridge_lights", [][3]float64{{0.0, 0.5, 1.0}})
		})
	}
}

func (s *Server) updateAlertLighting(level int) {
	colors := map[int][3]float64{
		0: {0.0, 0.5, 1.0},
		1: {1.0, 1.0, 0.0},
		2: {1.0, 0.5, 0.0},
		3: {1.0, 0.0, 0.0},
	}

	if color, exists := colors[level]; exists {
		s.panelManager.SetRGBStrip("tactical_weapons", "alert_lights", [][3]float64{color})
		s.panelManager.SetRGBStrip("captain_console", "bridge_lights", [][3]float64{color})
	}

	if level >= 2 {
		s.panelManager.SetBuzzer("captain_console", "alert_klaxon", 440, 2.0)
	}
}

func (s *Server) handleStatus(w http.ResponseWriter, r *http.Request) {
	status := map[string]interface{}{
		"running":           s.running,
		"uptime":            time.Since(time.Now()).Seconds(),
		"connected_clients": s.wsServer.GetConnectedStations(),
		"connected_panels":  s.tcpServer.GetConnectedPanels(),
		"universe_objects":  len(s.universe.Objects),
		"active_mission":    s.luaEngine.GetActiveMission(),
	}

	w.Header().Set("Content-Type", "application/json")
	writeJSON(w, status)
}

func (s *Server) handleUniverseState(w http.ResponseWriter, r *http.Request) {
	state := s.universe.GetState()
	w.Header().Set("Content-Type", "application/json")
	writeJSON(w, state)
}

func (s *Server) handleStations(w http.ResponseWriter, r *http.Request) {
	stations := s.stationManager.GetAllStations()
	w.Header().Set("Content-Type", "application/json")
	writeJSON(w, stations)
}

func (s *Server) handlePanels(w http.ResponseWriter, r *http.Request) {
	panels := s.panelManager.GetAllPanels()
	w.Header().Set("Content-Type", "application/json")
	writeJSON(w, panels)
}

func (s *Server) handleMissions(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET":
		missions := s.luaEngine.GetMissions()
		w.Header().Set("Content-Type", "application/json")
		writeJSON(w, missions)
	case "POST":
		var missionData networking.MissionLoadData
		if err := readJSON(r, &missionData); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}

		if err := s.luaEngine.LoadMissionFile(missionData.MissionFile); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		w.WriteHeader(http.StatusOK)
	}
}

func (s *Server) handleConfig(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET":
		w.Header().Set("Content-Type", "application/json")
		writeJSON(w, s.config)
	case "PUT":
		var newConfig config.Config
		if err := readJSON(r, &newConfig); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}

		s.config = &newConfig
		w.WriteHeader(http.StatusOK)
	}
}

func corsMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next(w, r)
	}
}

func writeJSON(w http.ResponseWriter, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(data); err != nil {
		log.Printf("JSON encode error: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
	}
}

func readJSON(r *http.Request, target interface{}) error {
	return json.NewDecoder(r.Body).Decode(target)
}

func (s *Server) LoadMission(filename string) error {
	return s.luaEngine.LoadMissionFile(filename)
}

func (s *Server) ExecuteLuaScript(script string) error {
	return s.luaEngine.ExecuteString(script)
}

func (s *Server) GetUniverse() *universe.Universe {
	return s.universe
}

func (s *Server) GetStationManager() *stations.StationManager {
	return s.stationManager
}

func (s *Server) GetPanelManager() *panels.PanelManager {
	return s.panelManager
}

func (s *Server) IsRunning() bool {
	s.mutex.RLock()
	defer s.mutex.RUnlock()
	return s.running
}
