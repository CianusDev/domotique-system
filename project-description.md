# 🏠 Projet Domotique ESP32 - Spécifications

## 📋 Vue d'ensemble

**Objectif :** Système domotique multi-utilisateurs avec capteurs extensibles, contrôlable via app Flutter  
**Caractéristiques :** Évolutif, sécurisé, ajout dynamique de capteurs sans recompilation

---

## 🏗️ Architecture Système

```
┌─────────────────────┐
│   App Flutter       │
│   (iOS/Android)     │
└──────────┬──────────┘
           │ Internet
┌──────────┴──────────┐
│  Backend NestJS     │
│  + PostgreSQL       │
│  + MQTT Broker      │
└──────────┬──────────┘
           │ MQTT
┌──────────┴──────────┐
│  ESP32 + Capteurs   │
│  + Actuateurs       │
└─────────────────────┘
```

---

## 🛠️ Stack Technologique

### Backend
- **NestJS** (TypeScript)
- **PostgreSQL** (base de données)
- **Mosquitto** (MQTT Broker)
- **JWT** (authentification)
- **WebSocket** (temps réel)

### App Mobile
- **Flutter 3.16+** (Dart)
- **Riverpod/Provider** (state management)
- **dio** (HTTP)
- **mqtt_client** (MQTT)
- **flutter_blue_plus** (BLE config WiFi)
- **fl_chart** (graphiques)

### Firmware ESP32
- **PlatformIO** (Arduino Framework)
- **PubSubClient** (MQTT)
- **ArduinoJson** (parsing)
- **Bibliothèques capteurs** (DHT, OneWire, etc.)
- **Architecture modulaire** (plugins capteurs)

### Hébergement
- **Dev :** PC local
- **Prod :** Railway/Render/Oracle Cloud (gratuit)

---

## 📦 Fonctionnalités Principales

### Backend
1. **Authentification & Multi-utilisateurs**
   - JWT, rôles, permissions
   
2. **Gestion ESP32**
   - CRUD devices, états temps réel
   
3. **Registry de Capteurs** ⭐
   - Catalogue types supportés (DHT22, PIR, DS18B20, etc.)
   - Spécifications techniques
   
4. **Gestion Dynamique Capteurs** ⭐
   - Ajout/suppression sans reflash
   - Configuration GPIO à distance
   - Calibration
   
5. **Collecte & Stockage Données**
   - Historiques multi-capteurs
   - Agrégations, statistiques
   
6. **Automatisations**
   - Règles IF/THEN multi-capteurs
   - Scènes, planifications
   
7. **Alertes**
   - Seuils configurables
   - Notifications push

### App Flutter
1. **Dashboard**
   - Vue d'ensemble temps réel
   - Widgets personnalisables
   
2. **Gestion ESP32**
   - Ajout via BLE
   - Configuration WiFi
   
3. **Gestion Capteurs** ⭐
   - Ajout/config capteurs dynamiques
   - Sélection type, pins GPIO
   - Test/calibration en direct
   
4. **Monitoring**
   - Graphiques temps réel
   - Historiques comparatifs
   - Analytics multi-capteurs
   
5. **Contrôle Actuateurs**
   - Lumières, prises, etc.
   
6. **Automatisations**
   - Création règles visuelles
   
7. **Multi-utilisateurs**
   - Partage devices, permissions

### Firmware ESP32
1. **Config WiFi BLE**
   - Setup initial sans code
   
2. **MQTT Client**
   - Pub/Sub dynamique
   
3. **Système Plugins Capteurs** ⭐
   - Architecture modulaire
   - Ajout capteurs à chaud
   - Drivers indépendants
   
4. **Gestion GPIO**
   - Allocation dynamique pins
   - Détection conflits
   
5. **Multi-Capteurs**
   - DHT22, PIR, DS18B20, LDR, HC-SR04, etc.
   - Extensible facilement
   
6. **OTA Updates**
   - Mises à jour sans câble

---

## 📡 Topics MQTT (Simplifié)

```
home/{device_id}/
├── status                    # État connexion
├── sensors/
│   ├── discovery            # Annonce nouveaux capteurs
│   ├── {sensor_id}/data     # Données capteur
│   └── control/add          # Ajouter capteur
└── actuators/
    └── {type}/cmd/state     # Commandes/états
```

---

## 🗄️ Base de Données (Tables Clés)

- **users** - Utilisateurs, auth
- **devices** - ESP32
- **sensor_types_registry** ⭐ - Catalogue capteurs
- **sensors** ⭐ - Capteurs configurés
- **sensor_data** - Historiques
- **actuators** - Actuateurs
- **automations** - Règles
- **alerts** - Alertes

---

## 🔐 API REST (Endpoints Principaux)

### Auth
- `POST /auth/login`, `/register`

### Devices
- `GET/POST /devices`
- `GET /devices/:id`

### Capteurs ⭐
- `GET /sensor-types` - Types disponibles
- `POST /devices/:id/sensors` - Ajouter capteur
- `GET /sensors/:id/history` - Historique

### Actuateurs
- `POST /actuators/:id/control`

### Automatisations
- `GET/POST /automations`

---

## 🎯 Flows Clés

### 1. Setup ESP32
1. Brancher ESP32 → Mode BLE
2. App scanne BLE → Configure WiFi
3. ESP32 se connecte → Backend détecte

### 2. Ajout Capteur ⭐
1. App: Sélectionner ESP32 → "Ajouter capteur"
2. Choisir type (DHT22, PIR...) + pin GPIO
3. App → Backend → MQTT → ESP32
4. ESP32 charge driver → Initialise → Confirme
5. Données temps réel dans app

### 3. Automatisation
1. Créer règle: "Si temp > 25°C → Ventilateur ON"
2. ESP32 publie données → Backend évalue
3. Condition vraie → Commande ventilateur

---

## 🧰 Matériel Essentiel

### Kit de base (~40€)
- ESP32 DevKit (~8€)
- Breadboard + câbles (~6€)
- Module relais (~2€)
- DHT22 (~5€)
- PIR (~3€)
- LED RGB (~3€)
- Alimentation 5V (~5€)
- Résistances (kit ~5€)

### Capteurs extensibles
DHT22, PIR, DS18B20, LDR, HC-SR04, BME280, MQ-2, Soil Moisture...

---

## 📁 Structure Projet

```
domotique-system/
├── backend/              # NestJS
│   ├── src/
│   │   ├── auth/
│   │   ├── devices/
│   │   ├── sensors/     # Module capteurs
│   │   ├── mqtt/
│   │   └── automations/
│
├── mobile-app/          # Flutter
│   ├── lib/
│   │   ├── screens/
│   │   │   └── sensor_management/  # Écrans capteurs
│   │   ├── services/
│   │   └── models/
│
└── esp32-firmware/      # ESP32
    ├── src/
    │   ├── main.cpp
    │   ├── sensor_manager.cpp  # Gestionnaire capteurs
    │   ├── sensors/            # Drivers capteurs
    │   │   ├── dht_sensor.cpp
    │   │   ├── pir_sensor.cpp
    │   │   └── ...
    │   └── actuators/
```
