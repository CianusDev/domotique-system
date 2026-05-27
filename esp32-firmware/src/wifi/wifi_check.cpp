#include "wifi_check.h"
#include <HTTPClient.h>

ConnectivityResult checkConnectivity() {
  HTTPClient http;
  http.setFollowRedirects(HTTPC_DISABLE_FOLLOW_REDIRECTS);
  http.setTimeout(5000);

  // Google's standard captive-portal probe — returns 204 No Content on real internet.
  if (!http.begin("http://connectivitycheck.gstatic.com/generate_204")) {
    http.end();
    Serial.println("[WiFi] Connectivity check: failed to init HTTP");
    return ConnectivityResult::NoInternet;
  }

  int code = http.GET();
  http.end();
  Serial.printf("[WiFi] Connectivity check: HTTP %d\n", code);

  if (code < 0) {
    // Negative = connection error (DNS fail, refused, timeout) — no internet
    return ConnectivityResult::NoInternet;
  }
  if (code == HTTP_CODE_NO_CONTENT) {
    return ConnectivityResult::Internet;
  }
  // Any other 2xx/3xx = captive portal intercept
  return ConnectivityResult::CaptivePortal;
}
