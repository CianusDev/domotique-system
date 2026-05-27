#pragma once
#include <Arduino.h>

/**
 * Result of a connectivity check after WiFi association.
 */
enum class ConnectivityResult {
  Internet,        // Reached Google's 204 endpoint cleanly → real internet
  NoInternet,      // Connection error / DNS fail — connected to AP but no internet
  CaptivePortal,   // HTTP responded with redirect/intercept (200/301/302…)
};

/**
 * Run a captive portal / internet connectivity check.
 * MUST be called while WiFi.status() == WL_CONNECTED.
 * Returns within ~5 seconds (timeout).
 */
ConnectivityResult checkConnectivity();
